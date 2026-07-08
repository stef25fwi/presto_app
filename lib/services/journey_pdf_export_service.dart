import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart' show XFile;

/// Génère le PDF export du "parcours personnalisé", réservé aux abonnements
/// IliPresto+ / ilipro (voir `JourneyEntitlements.canExportPdf`).
///
/// Le document embarque systématiquement le logo iliPresto et un filigrane
/// "ILIPRESTO+" pour rappeler que ce contenu est réservé à un usage
/// personnel et lié à l'abonnement de l'utilisateur.
///
/// Retourne un `XFile` prêt à partager, en gérant les deux plateformes :
/// - sur **web**, un `XFile.fromData` (octets en mémoire) — `path_provider`
///   et `dart:io` n'y sont pas disponibles ;
/// - sur **mobile**, les octets sont écrits dans le répertoire temporaire
///   (nécessaire pour que `Share.shareXFiles` puisse partager un vrai chemin
///   de fichier natif) puis exposés via `XFile(path)`.
class JourneyPdfExportService {
  const JourneyPdfExportService();

  static const _logoAssetPath = 'assets/images/logo_ilipresto.png';
  // Police TTF Unicode obligatoire : les polices Type1 par défaut du package
  // `pdf` (Helvetica) ne couvrent pas toute la typographie française présente
  // dans les fiches (apostrophes courbes « ’ », tirets cadratins « — »,
  // guillemets « « » », « € », etc.), ce qui faisait échouer `document.save()`
  // dès qu'un glyphe manquait.
  static const _fontRegularPath = 'assets/fonts/Inter-Regular.ttf';
  static const _fontBoldPath = 'assets/fonts/Inter-Bold.ttf';

  Future<XFile> generateJourneyPdf(Map<String, dynamic> journey) async {
    final bytes = await _buildPdfBytes(journey);
    const fileName = 'parcours_ilipresto.pdf';

    if (kIsWeb) {
      return XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/pdf',
      );
    }

    // Mobile : un vrai chemin de fichier est nécessaire pour le partage natif.
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/parcours_ilipresto_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, mimeType: 'application/pdf', name: fileName);
  }

  Future<Uint8List> _buildPdfBytes(Map<String, dynamic> journey) async {
    final baseFont = pw.Font.ttf(await rootBundle.load(_fontRegularPath));
    final boldFont = pw.Font.ttf(await rootBundle.load(_fontBoldPath));
    final logoBytes = await rootBundle.load(_logoAssetPath);
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    final recommendation =
        (journey['recommendation'] as Map?)?.cast<String, dynamic>() ??
            const {};
    final costs =
        (journey['costs'] as Map?)?.cast<String, dynamic>() ?? const {};
    final plan30 = (journey['plan30'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        const <Map<String, dynamic>>[];
    final aides = (journey['aides'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        const <Map<String, dynamic>>[];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: 0.6,
                    child: pw.Opacity(
                      opacity: 0.08,
                      child: pw.Text(
                        'ILIPRESTO+',
                        style: pw.TextStyle(
                          fontSize: 90,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(logoImage, width: 44, height: 44),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Text(
                          'Mon parcours personnalisé',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Document généré par iliPresto — abonnement IliPresto+, usage personnel',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  _sectionTitle('Résumé de ma situation'),
                  _kv('Projet', '${journey['projectLabel'] ?? ''}'),
                  _kv('Région', '${journey['region'] ?? ''}'),
                  _kv('Statut actuel', '${journey['currentStatus'] ?? ''}'),
                  _kv('Activité', '${journey['selectedActivity'] ?? ''}'),
                  pw.SizedBox(height: 14),
                  _sectionTitle('Statut recommandé'),
                  pw.Text(
                    '${recommendation['statut'] ?? '—'}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  if ('${recommendation['why'] ?? ''}'.isNotEmpty)
                    pw.Text('${recommendation['why']}'),
                  pw.SizedBox(height: 14),
                  if (costs.isNotEmpty) ...[
                    _sectionTitle('Coûts estimés'),
                    ...costs.entries
                        .where((e) => e.key != 'formalitesEstimees')
                        .map((e) => pw.Text('${e.key} : ${e.value}')),
                    pw.SizedBox(height: 14),
                  ],
                  if (plan30.isNotEmpty) ...[
                    _sectionTitle('Plan d\'action 30 jours'),
                    ...plan30.map(
                      (task) =>
                          pw.Text('- ${task['week']} : ${task['label']}'),
                    ),
                    pw.SizedBox(height: 14),
                  ],
                  if (aides.isNotEmpty) ...[
                    _sectionTitle('Aides identifiées'),
                    ...aides.map(
                      (aide) => pw.Text('- ${aide['name']} : ${aide['desc']}'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget _kv(String label, String value) {
    if (value.isEmpty) return pw.SizedBox(width: 0, height: 0);
    return pw.Text('$label : $value');
  }
}
