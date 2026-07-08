import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Génère le PDF export du "parcours personnalisé", réservé aux abonnements
/// IliPresto+ / ilipro (voir `JourneyEntitlements.canExportPdf`).
///
/// Le document embarque systématiquement le logo iliPresto et un filigrane
/// "ILIPRESTO+" pour rappeler que ce contenu est réservé à un usage
/// personnel et lié à l'abonnement de l'utilisateur.
class JourneyPdfExportService {
  const JourneyPdfExportService();

  static const _logoAssetPath = 'assets/images/logo_ilipresto.png';

  Future<File> generateJourneyPdf(Map<String, dynamic> journey) async {
    final logoBytes = await rootBundle.load(_logoAssetPath);
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final document = pw.Document();

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

    final Uint8List bytes = await document.save();
    // Répertoire documents de l'app (persistant) plutôt que temporaire, pour
    // que le PDF reste réellement enregistré sur l'appareil et pas seulement
    // le temps du partage.
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/parcours_ilipresto_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
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
