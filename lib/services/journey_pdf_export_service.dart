import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Génère le PDF export du "parcours personnalisé", réservé aux abonnements
/// IliPresto+ / ilipro (voir `JourneyEntitlements.canExportPdf`).
///
/// Le document embarque systématiquement :
/// - le logo iliprestō en couverture et dans l'en-tête de chaque page ;
/// - un filigrane/watermark discret iliprestō sur chaque page ;
/// - une présentation structurée en sections lisibles.
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
    final fileName = _fileNameForJourney(journey);

    return XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf');
  }

  /// Génère puis enregistre réellement le PDF sur la plateforme courante.
  ///
  /// Le partage système n'est pas un téléchargement fiable sur tous les
  /// navigateurs et appareils. `saveFile` reçoit donc directement les octets :
  /// téléchargement navigateur sur le web et sélecteur d'enregistrement sur
  /// les plateformes natives.
  ///
  /// Retourne `false` uniquement lorsque l'utilisateur annule le sélecteur
  /// natif. Sur le web, `saveFile` retourne `null` après avoir déclenché le
  /// téléchargement ; l'absence d'exception constitue donc le succès.
  Future<bool> downloadJourneyPdf(Map<String, dynamic> journey) async {
    final bytes = await _buildPdfBytes(journey);
    if (bytes.isEmpty) {
      throw StateError('Le document PDF généré est vide.');
    }

    final savedPath = await FilePicker.saveFile(
      dialogTitle: 'Télécharger mon parcours personnalisé',
      fileName: _fileNameForJourney(journey),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );

    return kIsWeb || savedPath != null;
  }

  static String _fileNameForJourney(Map<String, dynamic> journey) {
    final safeActivity = _sanitizeFilePart(
      '${journey['selectedActivity'] ?? ''}',
    );
    final suffix = safeActivity.isEmpty ? 'parcours' : safeActivity;
    return 'ilipresto_$suffix.pdf';
  }

  Future<Uint8List> _buildPdfBytes(Map<String, dynamic> journey) async {
    final baseFont = pw.Font.ttf(await rootBundle.load(_fontRegularPath));
    final boldFont = pw.Font.ttf(await rootBundle.load(_fontBoldPath));
    final logoBytes = await rootBundle.load(_logoAssetPath);
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    final recommendation = _map(journey['recommendation']);
    final costs = _map(journey['costs']);
    final summary = _map(journey['summary']);
    final recommendedLegalStatus = _map(journey['recommendedLegalStatus']);
    final blockingAlerts = _stringList(journey['blockingAlerts']);
    final plan30 = _mapList(journey['plan30']);
    final aides = _mapList(journey['aides']);
    final regulationTutorial = _mapList(journey['regulationTutorial']);
    final statusWarnings = _mapList(journey['statusWarnings']);
    final steps = _mapList(journey['steps']);

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(30, 56, 30, 48),
          buildBackground: (context) => _watermark(),
        ),
        header: (context) => _header(logoImage),
        footer: (context) => _footer(context, logoImage),
        build: (context) => [
          _coverBlock(logoImage, journey),
          _sectionTitle('Résumé de ma situation'),
          _kv('Projet', '${journey['projectLabel'] ?? ''}'),
          _kv('Région', '${journey['region'] ?? ''}'),
          _kv('Statut actuel', '${journey['currentStatus'] ?? ''}'),
          _kv('Activité', '${journey['selectedActivity'] ?? ''}'),
          pw.SizedBox(height: 14),
          _sectionTitle('Recommandation'),
          _highlightBox(
            title: 'Statut conseillé',
            text:
                '${recommendation['statut'] ?? recommendation['recommended'] ?? '—'}',
          ),
          if ('${recommendation['why'] ?? recommendation['justification'] ?? ''}'
              .trim()
              .isNotEmpty)
            _paragraph(
              '${recommendation['why'] ?? recommendation['justification']}',
            ),
          if ('${recommendation['planB'] ?? ''}'.trim().isNotEmpty)
            _kv('Alternative possible', '${recommendation['planB']}'),
          if (recommendedLegalStatus.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _kv(
              'Statut juridique recommandé',
              '${recommendedLegalStatus['recommended'] ?? recommendedLegalStatus['statut'] ?? '—'}',
            ),
            if ('${recommendedLegalStatus['justification'] ?? ''}'
                .trim()
                .isNotEmpty)
              _paragraph('${recommendedLegalStatus['justification']}'),
          ],
          if (blockingAlerts.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Alertes importantes'),
            ...blockingAlerts.map((alert) => _bullet(alert)),
          ],
          if (summary.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Résumé du parcours'),
            ...summary.entries.map(
              (entry) =>
                  _kv(_prettyLabel(entry.key), _formatValue(entry.value)),
            ),
          ],
          if (costs.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Coûts et points financiers'),
            ...costs.entries.map(
              (entry) =>
                  _kv(_prettyLabel(entry.key), _formatValue(entry.value)),
            ),
          ],
          if (regulationTutorial.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Réglementation et démarches'),
            ...regulationTutorial.map(_timelineItem),
          ],
          if (statusWarnings.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Points de vigilance liés au statut'),
            ...statusWarnings.map(_timelineItem),
          ],
          if (aides.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Aides possibles'),
            ...aides.map(_timelineItem),
          ],
          if (plan30.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Plan d’action 30 jours'),
            ...plan30.map(_timelineItem),
          ],
          if (steps.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _sectionTitle('Étapes détaillées'),
            ...steps.map(_timelineItem),
          ],
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _header(pw.ImageProvider logoImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Image(logoImage, width: 22, height: 22),
          pw.SizedBox(width: 8),
          _brandWordmark(fontSize: 13),
          pw.Spacer(),
          pw.Text(
            'Parcours personnalisé',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context, pw.ImageProvider logoImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Image(logoImage, width: 16, height: 16),
          pw.SizedBox(width: 6),
          pw.Text(
            'Document généré par iliprestō — usage personnel',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Spacer(),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _watermark() {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 44,
            top: 190,
            child: pw.Transform.rotate(
              angle: -0.55,
              child: pw.Opacity(
                opacity: 0.055,
                child: pw.Text(
                  'ILIPRESTŌ',
                  style: pw.TextStyle(
                    fontSize: 92,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange600,
                  ),
                ),
              ),
            ),
          ),
          pw.Positioned(
            right: 26,
            bottom: 170,
            child: pw.Transform.rotate(
              angle: -0.55,
              child: pw.Opacity(
                opacity: 0.035,
                child: pw.Text(
                  'ILIPRESTŌ',
                  style: pw.TextStyle(
                    fontSize: 58,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _coverBlock(
    pw.ImageProvider logoImage,
    Map<String, dynamic> journey,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColors.orange200, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logoImage, width: 44, height: 44),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _brandWordmark(fontSize: 20),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Mon parcours personnalisé',
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Fiche sauvegardée et exportée avec logo + filigrane iliprestō.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          _kv('Activité', '${journey['selectedActivity'] ?? ''}'),
          _kv('Région', '${journey['region'] ?? ''}'),
          _kv('Statut actuel', '${journey['currentStatus'] ?? ''}'),
        ],
      ),
    );
  }

  pw.Widget _brandWordmark({required double fontSize}) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: 'ili',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange600,
            ),
          ),
          pw.TextSpan(
            text: 'prestō',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.blue100, width: 0.5),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
      );

  pw.Widget _highlightBox({required String title, required String text}) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.blue100, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            text,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _paragraph(String text) {
    if (text.trim().isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
      ),
    );
  }

  pw.Widget _kv(String label, String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned == 'null') {
      return pw.SizedBox(width: 0, height: 0);
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label : ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.TextSpan(text: cleaned, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Expanded(child: _paragraph(text)),
        ],
      ),
    );
  }

  pw.Widget _timelineItem(Map<String, dynamic> item) {
    final title =
        '${item['title'] ?? item['label'] ?? item['name'] ?? 'Étape'}';
    final description =
        '${item['description'] ?? item['text'] ?? item['summary'] ?? item['desc'] ?? item['objective'] ?? ''}'
            .trim();
    final todos = _stringList(item['todos']);
    final checks = _stringList(item['checks']);

    // Le bloc détaillé doit pouvoir se répartir sur plusieurs pages.
    // Un Container unique rendait l'étape entière insécable et pouvait faire
    // échouer document.save() lorsque la checklist dépassait une page A4.
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(9),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        if (description.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _paragraph(description),
        ],
        ...todos.map(_bullet),
        ...checks.map(_bullet),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => '$item').toList();
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const <String>[];
  }

  static String _prettyLabel(String raw) {
    final spaced = raw
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .trim();
    if (spaced.isEmpty) return 'Information';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String _formatValue(dynamic value) {
    if (value is Map) {
      return value.entries
          .map((entry) => '${_prettyLabel(entry.key)} : ${entry.value}')
          .join(' · ');
    }
    if (value is List) return value.map((item) => '$item').join(' · ');
    return '$value';
  }

  static String _sanitizeFilePart(String raw) {
    final cleaned = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? '' : cleaned;
  }
}
