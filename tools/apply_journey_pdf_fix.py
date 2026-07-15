#!/usr/bin/env python3
"""Applique le correctif génération/téléchargement des PDF parcours."""

from pathlib import Path


def replace_once(text: str, before: str, after: str, label: str) -> str:
    if after in text:
        return text
    if before not in text:
        raise SystemExit(f"Bloc introuvable: {label}")
    return text.replace(before, after, 1)


service_path = Path("lib/services/journey_pdf_export_service.dart")
service = service_path.read_text(encoding="utf-8")
service = replace_once(
    service,
    "import 'package:cross_file/cross_file.dart';\nimport 'package:flutter/services.dart' show rootBundle;",
    "import 'package:cross_file/cross_file.dart';\nimport 'package:file_picker/file_picker.dart';\nimport 'package:flutter/foundation.dart' show kIsWeb;\nimport 'package:flutter/services.dart' show rootBundle;",
    "imports service PDF",
)
service = replace_once(
    service,
    """  Future<XFile> generateJourneyPdf(Map<String, dynamic> journey) async {
    final bytes = await _buildPdfBytes(journey);
    final safeActivity = _sanitizeFilePart(
      '${journey['selectedActivity'] ?? ''}',
    );
    final suffix = safeActivity.isEmpty ? 'parcours' : safeActivity;
    final fileName = 'ilipresto_$suffix.pdf';

    return XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf');
  }
""",
    """  Future<XFile> generateJourneyPdf(Map<String, dynamic> journey) async {
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

    final savedPath = await FilePicker.platform.saveFile(
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
""",
    "méthodes génération/téléchargement",
)
service = replace_once(
    service,
    """    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(9),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
          ),
          if (description.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            _paragraph(description),
          ],
          ...todos.map(_bullet),
          ...checks.map(_bullet),
        ],
      ),
    );
""",
    """    // Le bloc détaillé doit pouvoir se répartir sur plusieurs pages.
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
""",
    "timeline PDF sécable",
)
service_path.write_text(service, encoding="utf-8")

account_path = Path("lib/pages/account/mon_entreprise_parcours_page.dart")
account = account_path.read_text(encoding="utf-8")
account = account.replace("import 'package:share_plus/share_plus.dart';\n", "", 1)
account = replace_once(
    account,
    """      final pdfFile = await _pdfExportService.generateJourneyPdf(snapshot);
      if (!mounted) return;
      closeLoadingDialog();

      final box = context.findRenderObject() as RenderBox?;
      final result = await Share.shareXFiles(
        [pdfFile],
        subject: 'Mon parcours personnalisé iliprestō',
        text: 'Voici mon parcours personnalisé généré par iliprestō.',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );

      if (result.status == ShareResultStatus.success) {
        await _entitlementsService.recordPdfExport();
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PDF généré : la fenêtre de sauvegarde/partage a été ouverte.',
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export PDF annulé.')),
        );
      }
""",
    """      final downloaded = await _pdfExportService.downloadJourneyPdf(snapshot);
      if (!mounted) return;
      closeLoadingDialog();

      if (downloaded) {
        await _entitlementsService.recordPdfExport();
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF généré et téléchargé avec succès.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléchargement PDF annulé.')),
        );
      }
""",
    "export PDF espace compte",
)
account_path.write_text(account, encoding="utf-8")

toolbox_path = Path("lib/pages/toolbox_je_me_lance_page.dart")
toolbox = toolbox_path.read_text(encoding="utf-8")
toolbox = toolbox.replace("import 'package:share_plus/share_plus.dart';\n", "", 1)
toolbox = replace_once(
    toolbox,
    """      // Le service renvoie un XFile prêt à partager (fichier temporaire sur
      // mobile, données en mémoire sur web), et un PDF avec police Unicode.
      final pdfFile = await _pdfExportService.generateJourneyPdf(
        _buildLocalSnapshot(),
      );
      await _entitlementsService.recordPdfExport();

      if (!context.mounted) return;
      await Share.shareXFiles([
        pdfFile,
      ], text: 'Mon parcours personnalisé — iliPresto+');
""",
    """      final downloaded = await _pdfExportService.downloadJourneyPdf(
        _buildLocalSnapshot(),
      );
      if (!context.mounted) return;

      if (!downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléchargement PDF annulé.')),
        );
        return;
      }

      await _entitlementsService.recordPdfExport();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parcours sauvegardé et PDF téléchargé.'),
        ),
      );
""",
    "export PDF résultat parcours",
)
toolbox = toolbox.replace(
    "  /// génère aussi un export PDF sur l'appareil et ouvre le menu de partage.\n",
    "  /// génère aussi un export PDF et ouvre le téléchargement/enregistrement.\n",
    1,
)
toolbox_path.write_text(toolbox, encoding="utf-8")

test_path = Path("test/services/journey_pdf_export_service_test.dart")
test = test_path.read_text(encoding="utf-8")
if "génère un PDF lorsque le contenu détaillé dépasse une page" not in test:
    insertion = """

  test('génère un PDF lorsque le contenu détaillé dépasse une page', () async {
    const service = JourneyPdfExportService();
    final file = await service.generateJourneyPdf({
      'projectLabel': 'Projet avec parcours détaillé',
      'region': 'Guadeloupe',
      'currentStatus': 'Fonctionnaire',
      'selectedActivity': 'Formation',
      'recommendation': {'statut': 'Micro-entreprise'},
      'steps': [
        {
          'title': 'Checklist complète',
          'description':
              'Cette étape longue vérifie la répartition sur plusieurs pages.',
          'todos': List<String>.generate(
            90,
            (index) =>
                'Action détaillée ${index + 1} : vérifier les documents, les règles et les justificatifs nécessaires.',
          ),
        },
      ],
    });

    final bytes = await file.readAsBytes();
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
"""
    final_brace = test.rfind("\n}")
    if final_brace == -1:
        raise SystemExit("Fin du fichier de test introuvable")
    test = test[:final_brace] + insertion + test[final_brace:]
test_path.write_text(test, encoding="utf-8")

print("journey PDF generation/download fix: OK")
