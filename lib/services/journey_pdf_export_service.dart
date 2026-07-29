import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'journey_pdf_download.dart';
import 'pdf/ilipresto_pdf_branding.dart';

/// Génère et télécharge le PDF du parcours personnalisé.
class JourneyPdfExportService {
  const JourneyPdfExportService();

  Future<XFile> generateJourneyPdf(Map<String, dynamic> journey) async {
    final bytes = await _buildPdfBytes(journey);
    return XFile.fromData(
      bytes,
      name: _fileNameForJourney(journey),
      mimeType: 'application/pdf',
    );
  }

  Future<bool> downloadJourneyPdf(Map<String, dynamic> journey) async {
    final bytes = await _buildPdfBytes(journey);
    if (bytes.isEmpty) {
      throw StateError('Le document PDF généré est vide.');
    }
    return saveJourneyPdfBytes(
      bytes: bytes,
      fileName: _fileNameForJourney(journey),
    );
  }

  static String _fileNameForJourney(Map<String, dynamic> journey) {
    final safeActivity = _sanitizeFilePart('${journey['selectedActivity'] ?? ''}');
    return 'ilipresto_${safeActivity.isEmpty ? 'parcours' : safeActivity}.pdf';
  }

  Future<Uint8List> _buildPdfBytes(Map<String, dynamic> journey) async {
    final branding = await IliprestoPdfBranding.load();
    final document = pw.Document(theme: branding.theme);
    final widgets = <pw.Widget>[
      _cover(branding, journey),
      _section('Résumé de ma situation'),
      _kv('Projet', journey['projectLabel']),
      _kv('Région', journey['region']),
      _kv('Statut actuel', journey['currentStatus']),
      _kv('Activité', journey['selectedActivity']),
    ];

    final recommendation = _map(journey['recommendation']);
    if (recommendation.isNotEmpty) {
      widgets.addAll([
        _section('Recommandation'),
        _highlight(
          'Statut conseillé',
          recommendation['statut'] ?? recommendation['recommended'] ?? '—',
        ),
        if (_text(recommendation['why'] ?? recommendation['justification']).isNotEmpty)
          _paragraph(recommendation['why'] ?? recommendation['justification']),
        _kv('Alternative possible', recommendation['planB']),
      ]);
    }

    _appendStringList(widgets, 'Alertes importantes', journey['blockingAlerts']);
    _appendMap(widgets, 'Résumé du parcours', journey['summary']);
    _appendMap(widgets, 'Coûts et points financiers', journey['costs']);
    _appendTimeline(widgets, 'Réglementation et démarches', journey['regulationTutorial']);
    _appendTimeline(widgets, 'Points de vigilance liés au statut', journey['statusWarnings']);
    _appendTimeline(widgets, 'Aides possibles', journey['aides']);
    _appendTimeline(widgets, 'Plan d’action 30 jours', journey['plan30']);
    _appendTimeline(widgets, 'Étapes détaillées', journey['steps']);
    widgets.add(
      branding.disclaimer(
        additionalText:
            'Ce parcours est construit à partir des informations déclarées par '
            'l’utilisateur et peut évoluer selon sa situation.',
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(30, 56, 30, 48),
          buildBackground: (_) => _watermark(),
        ),
        header: (_) => branding.header(documentTitle: 'Mon parcours personnalisé'),
        footer: branding.footer,
        build: (_) => widgets,
      ),
    );
    return document.save();
  }

  static pw.Widget _cover(
    IliprestoPdfBranding branding,
    Map<String, dynamic> journey,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      margin: const pw.EdgeInsets.only(bottom: 16),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColors.orange200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Image(branding.logo, width: 44, height: 44),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'iliprestō',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: IliprestoPdfBranding.orange,
                      ),
                    ),
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
          _kv('Activité', journey['selectedActivity']),
          _kv('Région', journey['region']),
          _kv('Statut actuel', journey['currentStatus']),
        ],
      ),
    );
  }

  static void _appendStringList(
    List<pw.Widget> target,
    String title,
    dynamic value,
  ) {
    final values = _stringList(value);
    if (values.isEmpty) return;
    target.add(_section(title));
    target.addAll(values.map(_bullet));
  }

  static void _appendMap(
    List<pw.Widget> target,
    String title,
    dynamic value,
  ) {
    final map = _map(value);
    if (map.isEmpty) return;
    target.add(_section(title));
    target.addAll(
      map.entries.map(
        (entry) => _kv(_prettyLabel(entry.key), _formatValue(entry.value)),
      ),
    );
  }

  static void _appendTimeline(
    List<pw.Widget> target,
    String title,
    dynamic value,
  ) {
    final items = _mapList(value);
    if (items.isEmpty) return;
    target.add(_section(title));
    for (final item in items) {
      final itemTitle = _text(
        item['title'] ?? item['label'] ?? item['name'] ?? item['week'] ?? 'Étape',
      );
      final description = _text(
        item['description'] ??
            item['text'] ??
            item['summary'] ??
            item['desc'] ??
            item['objective'],
      );
      target.add(_timelineTitle(itemTitle));
      if (description.isNotEmpty) target.add(_paragraph(description));
      target.addAll(_stringList(item['todos']).map(_bullet));
      target.addAll(_stringList(item['checks']).map(_bullet));
      target.add(pw.SizedBox(height: 8));
    }
  }

  static pw.Widget _watermark() => pw.FullPage(
        ignoreMargins: true,
        child: pw.Center(
          child: pw.Transform.rotate(
            angle: -0.55,
            child: pw.Opacity(
              opacity: 0.05,
              child: pw.Text(
                'ILIPRESTŌ',
                style: pw.TextStyle(
                  fontSize: 90,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange600,
                ),
              ),
            ),
          ),
        ),
      );

  static pw.Widget _section(String text) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 7),
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget _highlight(String title, dynamic value) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        margin: const pw.EdgeInsets.only(bottom: 8),
        color: PdfColors.blue50,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(_text(value), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _timelineTitle(String title) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(9),
        color: PdfColors.grey100,
        child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _paragraph(dynamic value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          _text(value),
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
        ),
      );

  static pw.Widget _kv(String label, dynamic value) {
    final text = _text(value);
    if (text.isEmpty || text == 'null') return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label : ',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: text, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _bullet(String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('• '),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
      );

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : const <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList()
      : const <Map<String, dynamic>>[];

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map(_text).where((item) => item.isNotEmpty).toList();
    }
    final text = _text(value);
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  static String _text(dynamic value) => value == null ? '' : '$value'.trim();

  static String _prettyLabel(String raw) {
    final spaced = raw
        .replaceAll('_', ' ')
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .trim();
    return spaced.isEmpty
        ? 'Information'
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  static String _formatValue(dynamic value) {
    if (value is Map) {
      return value.entries
          .map((entry) => '${_prettyLabel('${entry.key}')} : ${entry.value}')
          .join(' · ');
    }
    if (value is List) return value.map(_text).join(' · ');
    return _text(value);
  }

  static String _sanitizeFilePart(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
