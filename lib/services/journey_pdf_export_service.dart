import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'journey_pdf_download.dart';

/// Génère et télécharge le guide PDF du parcours personnalisé.
///
/// Le document est volontairement structuré comme un accompagnement :
/// 1. décision de départ ;
/// 2. points bloquants ;
/// 3. calendrier 30 jours ;
/// 4. étapes chronologiques ;
/// 5. modèles de courriers ;
/// 6. sources officielles.
///
/// Les informations répétées sont normalisées et dédupliquées avant rendu.
class JourneyPdfExportService {
  const JourneyPdfExportService();

  static const _logoAssetPath = 'assets/images/logo_ilipresto.png';
  static const _fontRegularPath = 'assets/fonts/Inter-Regular.ttf';
  static const _fontBoldPath = 'assets/fonts/Inter-Bold.ttf';

  static const _stepOrder = <String>[
    'reglementation',
    'situation',
    'offres',
    'aides',
    'statut_lancement',
    'preparation',
    'declaration',
    'protections',
    'gestion',
    'lancement',
  ];

  static const _stepTitles = <String, String>{
    'reglementation': 'Vérifier que vous pouvez exercer l’activité',
    'situation': 'Sécuriser votre situation personnelle',
    'offres': 'Valider votre offre, vos prix et votre budget',
    'aides': 'Vérifier les aides avant de créer l’activité',
    'statut_lancement': 'Choisir le cadre juridique et fiscal',
    'preparation': 'Préparer le dossier de création',
    'declaration': 'Déclarer officiellement l’activité',
    'protections': 'Mettre en place les protections obligatoires ou utiles',
    'gestion': 'Organiser la gestion et les obligations récurrentes',
    'lancement': 'Lancer une première prestation maîtrisée',
  };

  static const _stepOutcomes = <String, String>{
    'reglementation':
        'Vous savez si l’activité est libre ou réglementée et quelles preuves sont nécessaires.',
    'situation':
        'Vous avez vérifié le cumul, obtenu les accords utiles et conservé une trace écrite.',
    'offres':
        'Votre offre, votre tarif et votre budget de démarrage sont cohérents.',
    'aides':
        'Vous avez vérifié les dispositifs à demander avant la création et leur calendrier.',
    'statut_lancement':
        'Vous avez choisi un statut et identifié les options fiscales et sociales à confirmer.',
    'preparation':
        'Toutes les pièces et informations sont prêtes avant l’ouverture du formulaire officiel.',
    'declaration':
        'La formalité est déposée et les justificatifs de dépôt sont archivés.',
    'protections':
        'Vous pouvez intervenir chez vos premiers clients avec les documents et assurances adaptés.',
    'gestion':
        'Vous savez quoi suivre chaque mois ou trimestre et quelles échéances anticiper.',
    'lancement':
        'La première mission reste limitée au périmètre autorisé, assuré et documenté.',
  };

  static const _labelOverrides = <String, String>{
    'region': 'Région',
    'currentStatus': 'Statut actuel',
    'activity': 'Activité',
    'vigilanceLevel': 'Niveau de vigilance',
    'recommendedPath': 'Parcours recommandé',
    'recommendedLegalStatus': 'Statut juridique recommandé',
    'formalitesEstimees': 'Formalités estimées',
    'annonceLegale': 'Annonce légale',
    'assuranceProAn': 'Assurance professionnelle / an',
    'comptableAn': 'Comptable / an',
    'banqueOutilsAn': 'Banque et outils / an',
    'ficheCoutsIndicatifs': 'Coûts propres à l’activité',
  };

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
    final safeActivity = _sanitizeFilePart(
      '${journey['selectedActivity'] ?? ''}',
    );
    return 'ilipresto_${safeActivity.isEmpty ? 'parcours' : safeActivity}.pdf';
  }

  Future<Uint8List> _buildPdfBytes(Map<String, dynamic> journey) async {
    final regular = pw.Font.ttf(await rootBundle.load(_fontRegularPath));
    final bold = pw.Font.ttf(await rootBundle.load(_fontBoldPath));
    final logoData = await rootBundle.load(_logoAssetPath);
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final recommendation = _map(journey['recommendation']);
    final blockingAlerts = _uniqueStrings(
      _expandList(journey['blockingAlerts']),
    );
    final summary = _map(journey['summary']);
    final costs = _map(journey['costs']);
    final regulationItems = _mapList(journey['regulationTutorial']);
    final statusWarnings = _mapList(journey['statusWarnings']);
    final aides = _deduplicateItems(_mapList(journey['aides']));
    final plan30 = _deduplicateItems(_mapList(journey['plan30']));
    final steps = _orderSteps(_deduplicateItems(_mapList(journey['steps'])));
    final sources = _extractSources(regulationItems);
    final regulationContent = regulationItems
        .where((item) => !_isSourceItem(item))
        .toList();
    final letterTemplates = _buildLetterTemplates(journey);

    final seenDetails = <String>{...blockingAlerts.map(_fingerprint)};

    final widgets = <pw.Widget>[
      _cover(logo, journey),
      _guideNotice(),
      _section('1. Votre situation et la décision de départ'),
      _profileSummary(journey, summary),
    ];

    if (recommendation.isNotEmpty) {
      widgets.add(_recommendationCard(recommendation));
    }

    if (blockingAlerts.isNotEmpty) {
      widgets.add(_section('2. À valider avant toute démarche'));
      widgets.add(
        _alertBox(
          'Ne poursuivez pas tant que ces points ne sont pas vérifiés',
          blockingAlerts,
        ),
      );
    }

    if (plan30.isNotEmpty) {
      widgets.add(_section('3. Votre feuille de route sur 30 jours'));
      widgets.addAll(_buildPlan30Widgets(plan30));
    }

    widgets.add(_section('4. Guide pas à pas'));
    final effectiveSteps = steps.isEmpty ? _fallbackSteps() : steps;
    for (var index = 0; index < effectiveSteps.length; index++) {
      final item = effectiveSteps[index];
      final id = _text(item['id']);
      final actions = _stepActions(
        item,
        id: id,
        regulationItems: regulationContent,
        statusWarnings: statusWarnings,
        costs: costs,
        aides: aides,
        seen: seenDetails,
      );
      final objective = _newText(
        _text(
          item['objective'] ??
              item['description'] ??
              item['summary'] ??
              item['desc'],
        ),
        seenDetails,
      );
      widgets.addAll(
        _stepCards(
          number: index + 1,
          title: _stepTitle(item, id),
          objective: objective,
          actions: actions,
          expectedResult:
              _stepOutcomes[id] ??
              'Vous disposez d’un résultat vérifiable avant de passer à l’étape suivante.',
        ),
      );
    }

    if (letterTemplates.isNotEmpty) {
      widgets.add(_section('5. Modèles de courriers et messages'));
      widgets.add(
        _paragraph(
          'Remplacez les éléments entre crochets, adaptez le contenu à votre situation et conservez une copie de chaque envoi.',
        ),
      );
      for (var index = 0; index < letterTemplates.length; index++) {
        if (index > 0) widgets.add(pw.NewPage());
        widgets.add(_letterTemplate(letterTemplates[index]));
      }
    }

    if (sources.isNotEmpty) {
      widgets.add(_section('6. Sources officielles à consulter'));
      widgets.add(
        _paragraph(
          'Vérifiez les conditions et les montants au moment de votre démarche : les règles peuvent évoluer.',
        ),
      );
      widgets.addAll(sources.map(_sourceLine));
    }

    widgets.add(_finalChecklist());
    widgets.add(_legalNotice());

    document.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(30, 56, 30, 48),
          buildBackground: (_) => _watermark(),
        ),
        header: (_) => _header(logo),
        footer: (context) => _footer(context, logo),
        build: (_) => widgets,
      ),
    );

    return document.save();
  }

  static pw.Widget _guideNotice() => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.blue50,
      border: pw.Border.all(color: PdfColors.blue200),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Text(
      'Comment utiliser ce guide : avancez dans l’ordre, cochez les actions réalisées et ne passez à l’étape suivante que lorsque le résultat attendu est obtenu.',
      style: const pw.TextStyle(fontSize: 10),
    ),
  );

  static pw.Widget _profileSummary(
    Map<String, dynamic> journey,
    Map<String, dynamic> summary,
  ) {
    final rows = <pw.Widget>[
      _kv('Projet', journey['projectLabel']),
      _kv('Activité', journey['selectedActivity']),
      _kv('Région', journey['region']),
      _kv('Statut actuel', journey['currentStatus']),
    ];

    for (final key in const ['vigilanceLevel', 'recommendedPath']) {
      if (summary.containsKey(key)) {
        rows.add(_kv(_prettyLabel(key), summary[key]));
      }
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  static pw.Widget _recommendationCard(Map<String, dynamic> recommendation) {
    final recommended = _text(
      recommendation['statut'] ?? recommendation['recommended'],
    );
    final why = _text(recommendation['why'] ?? recommendation['justification']);
    final planB = _text(recommendation['planB']);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border.all(color: PdfColors.orange300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Orientation de départ',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          if (recommended.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              recommended,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ],
          if (why.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              why,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
            ),
          ],
          if (planB.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _kv('Alternative à étudier', planB),
          ],
          pw.SizedBox(height: 4),
          pw.Text(
            'Décision attendue : confirmer ce choix avec l’organisme compétent ou un professionnel lorsque la situation le nécessite.',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _alertBox(String title, List<String> alerts) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    margin: const pw.EdgeInsets.only(bottom: 10),
    decoration: pw.BoxDecoration(
      color: PdfColors.red50,
      border: pw.Border.all(color: PdfColors.red300),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red800,
          ),
        ),
        pw.SizedBox(height: 7),
        ...alerts.map(_checkLine),
      ],
    ),
  );

  static List<pw.Widget> _buildPlan30Widgets(List<Map<String, dynamic>> plan) {
    final grouped = <String, List<String>>{};
    for (final item in plan) {
      final week = _text(item['week'] ?? item['title']);
      final task = _text(
        item['label'] ??
            item['description'] ??
            item['text'] ??
            item['objective'] ??
            item['name'],
      );
      if (task.isEmpty) continue;
      grouped.putIfAbsent(week.isEmpty ? 'À planifier' : week, () => []);
      grouped[week.isEmpty ? 'À planifier' : week]!.add(task);
    }

    final widgets = <pw.Widget>[];
    for (final entry in grouped.entries) {
      final tasks = _uniqueStrings(entry.value);
      if (tasks.isEmpty) continue;
      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                entry.key,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 5),
              ...tasks.map(_checkLine),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  static List<pw.Widget> _stepCards({
    required int number,
    required String title,
    required String objective,
    required List<String> actions,
    required String expectedResult,
  }) {
    const maxActionsPerCard = 4;
    const maxCharactersPerCard = 1100;
    final chunks = <List<String>>[];

    if (actions.isEmpty) {
      chunks.add(const <String>[]);
    } else {
      var current = <String>[];
      var currentCharacters = 0;
      for (final action in actions.expand(_splitLongAction)) {
        final wouldOverflowCount = current.length >= maxActionsPerCard;
        final wouldOverflowText =
            current.isNotEmpty &&
            currentCharacters + action.length > maxCharactersPerCard;
        if (wouldOverflowCount || wouldOverflowText) {
          chunks.add(current);
          current = <String>[];
          currentCharacters = 0;
        }
        current.add(action);
        currentCharacters += action.length;
      }
      if (current.isNotEmpty) {
        chunks.add(current);
      }
    }

    return [
      for (var index = 0; index < chunks.length; index++)
        _stepCardChunk(
          heading: index == 0
              ? 'Étape $number - $title'
              : 'Étape $number - $title (suite ${index + 1})',
          objective: index == 0 ? objective : '',
          actions: chunks[index],
          expectedResult: index == chunks.length - 1 ? expectedResult : '',
        ),
    ];
  }

  static Iterable<String> _splitLongAction(String action) sync* {
    const maxCharacters = 850;
    final normalized = action.trim();
    if (normalized.length <= maxCharacters) {
      if (normalized.isNotEmpty) yield normalized;
      return;
    }

    var remaining = normalized;
    while (remaining.length > maxCharacters) {
      var cut = remaining.lastIndexOf(' ', maxCharacters);
      if (cut < maxCharacters ~/ 2) {
        cut = maxCharacters;
      }
      yield remaining.substring(0, cut).trim();
      remaining = remaining.substring(cut).trim();
    }
    if (remaining.isNotEmpty) yield remaining;
  }

  static pw.Widget _stepCardChunk({
    required String heading,
    required String objective,
    required List<String> actions,
    required String expectedResult,
  }) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(10),
                topRight: pw.Radius.circular(10),
              ),
            ),
            child: pw.Text(
              heading,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(11),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (objective.isNotEmpty) ...[
                  _miniHeading('Objectif'),
                  _paragraph(objective),
                ],
                if (actions.isNotEmpty) ...[
                  _miniHeading('Actions à réaliser'),
                  ...actions.map(_checkLine),
                ],
                if (expectedResult.isNotEmpty) ...[
                  _miniHeading('Résultat attendu avant de continuer'),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green200),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      expectedResult,
                      style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _stepActions(
    Map<String, dynamic> item, {
    required String id,
    required List<Map<String, dynamic>> regulationItems,
    required List<Map<String, dynamic>> statusWarnings,
    required Map<String, dynamic> costs,
    required List<Map<String, dynamic>> aides,
    required Set<String> seen,
  }) {
    final values = <String>[
      ..._expandList(item['todos']),
      ..._expandList(item['checks']),
    ];

    if (id == 'reglementation') {
      for (final regulation in regulationItems) {
        final title = _text(
          regulation['title'] ?? regulation['label'] ?? regulation['name'],
        );
        final description = _text(
          regulation['description'] ??
              regulation['text'] ??
              regulation['summary'] ??
              regulation['desc'],
        );
        if (description.isEmpty) continue;
        values.add(title.isEmpty ? description : '$title : $description');
      }
    }

    if (id == 'situation') {
      for (final warning in statusWarnings) {
        final title = _text(
          warning['title'] ?? warning['label'] ?? warning['name'],
        );
        final description = _text(
          warning['description'] ?? warning['text'] ?? warning['summary'],
        );
        if (description.isNotEmpty) {
          values.add(title.isEmpty ? description : '$title : $description');
        }
        values.addAll(_expandList(warning['checks']));
      }
    }

    if (id == 'offres') {
      values.addAll(_costLines(costs));
    }

    if (id == 'aides') {
      values.addAll(_aidLines(aides));
    }

    final result = <String>[];
    for (final raw in _uniqueStrings(values)) {
      final cleaned = raw.trim();
      if (cleaned.isEmpty) continue;
      final key = _fingerprint(cleaned);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(cleaned);
    }
    return result;
  }

  static List<String> _costLines(Map<String, dynamic> costs) {
    if (costs.isEmpty) return const [];

    final lines = <String>[];
    for (final entry in costs.entries) {
      if (entry.key == 'note' || entry.key == 'ficheCoutsIndicatifs') continue;
      final formatted = _formatCostValue(entry.value);
      if (formatted.isEmpty) continue;
      lines.add('${_prettyLabel(entry.key)} : $formatted');
    }

    final detailed = _expandList(costs['ficheCoutsIndicatifs']);
    if (detailed.isNotEmpty) {
      lines.addAll(detailed);
    } else {
      lines.addAll(_expandList(costs['note']));
    }

    return _uniqueStrings(lines);
  }

  static String _formatCostValue(dynamic value) {
    if (value is Map) {
      final map = value.cast<dynamic, dynamic>();
      final min = _text(map['min']);
      final max = _text(map['max']);
      if (min.isNotEmpty && max.isNotEmpty) return '$min € à $max €';
      return map.entries
          .map((entry) => '${_prettyLabel('${entry.key}')} : ${entry.value}')
          .join(' - ');
    }
    if (value is num) return '${_formatNumber(value)} €';
    if (value is List) return _uniqueStrings(value.map(_text)).join(' - ');
    return _text(value);
  }

  static String _formatNumber(num value) {
    if (value == value.roundToDouble()) return '${value.toInt()}';
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  static List<String> _aidLines(List<Map<String, dynamic>> aides) {
    final result = <String>[];
    for (final aide in aides) {
      final name = _text(
        aide['name'] ?? aide['title'] ?? aide['label'] ?? aide['week'],
      );
      var description = _text(
        aide['desc'] ??
            aide['description'] ??
            aide['text'] ??
            aide['summary'] ??
            aide['objective'],
      );
      if (_fingerprint(
        description,
      ).startsWith(_fingerprint('Dispositif identifié pour l’activité'))) {
        description = '';
      }
      if (name.isEmpty && description.isEmpty) continue;
      result.add(
        name.isEmpty || description.isEmpty
            ? '$name$description'
            : '$name : $description',
      );
    }
    return _uniqueStrings(result);
  }

  static List<Map<String, dynamic>> _orderSteps(
    List<Map<String, dynamic>> steps,
  ) {
    final indexed = <String, Map<String, dynamic>>{};
    final extras = <Map<String, dynamic>>[];
    for (final item in steps) {
      final id = _text(item['id']);
      if (id.isEmpty || !_stepOrder.contains(id)) {
        extras.add(item);
      } else {
        indexed.putIfAbsent(id, () => item);
      }
    }

    return [
      for (final id in _stepOrder)
        if (indexed.containsKey(id)) indexed[id]!,
      ...extras,
    ];
  }

  static List<Map<String, dynamic>> _fallbackSteps() => [
    for (final id in _stepOrder)
      <String, dynamic>{
        'id': id,
        'title': _stepTitles[id],
        'objective': _stepOutcomes[id],
      },
  ];

  static String _stepTitle(Map<String, dynamic> item, String id) {
    if (_stepTitles.containsKey(id)) return _stepTitles[id]!;
    return _text(
      item['title'] ?? item['label'] ?? item['name'] ?? 'Étape à réaliser',
    );
  }

  static List<Map<String, dynamic>> _buildLetterTemplates(
    Map<String, dynamic> journey,
  ) {
    final status = _text(journey['currentStatus']).toLowerCase();
    final activity = _text(journey['selectedActivity']);
    final region = _text(journey['region']);
    final templates = <Map<String, dynamic>>[];

    if (status.contains('salari')) {
      templates.add({
        'title': 'Demande de confirmation écrite à l’employeur',
        'use':
            'À utiliser en cas de clause, de doute sur la concurrence, la clientèle, les horaires ou les moyens utilisés.',
        'subject':
            'Objet : vérification de la compatibilité d’une activité indépendante',
        'body': '''Madame, Monsieur,

Je souhaite exercer, en dehors de mon temps de travail, une activité indépendante de [activité précise] dans la zone de [territoire].

Cette activité sera exercée sans utilisation des moyens, fichiers, outils, informations ou contacts de l’employeur et dans le respect de mon obligation de loyauté.

Je vous remercie de bien vouloir me confirmer par écrit si mon contrat de travail, ses avenants ou les règles applicables dans l’entreprise prévoient une restriction, une autorisation préalable ou des conditions particulières.

Je reste disponible pour vous transmettre une description plus détaillée de l’activité envisagée.

Cordialement,
[Nom, prénom]
[Poste]
[Coordonnées]''',
      });
    } else if (status.contains('fonctionnaire') ||
        status.contains('agent public')) {
      templates.add({
        'title': 'Demande d’autorisation de cumul d’activités',
        'use':
            'À adapter aux règles de votre administration et à transmettre par la voie prévue par votre employeur public.',
        'subject': 'Objet : demande d’autorisation de cumul d’activités',
        'body': '''Madame, Monsieur,

Je sollicite l’autorisation d’exercer, à titre accessoire, une activité de [activité précise] en dehors de mes heures de service.

L’activité serait exercée sous la forme [statut envisagé], dans la zone de [territoire], pour un volume prévisionnel de [nombre] heures par semaine.

Je m’engage à respecter mes obligations de neutralité, de discrétion, de loyauté et de bon fonctionnement du service, ainsi qu’à ne pas utiliser les moyens ou informations de l’administration.

Vous trouverez ci-joint la description de l’activité, les horaires prévus et les informations utiles à l’instruction de ma demande.

Cordialement,
[Nom, prénom]
[Corps / grade / service]
[Coordonnées]''',
      });
    } else if (status.contains('demandeur')) {
      templates.add({
        'title': 'Demande de rendez-vous à France Travail',
        'use':
            'À envoyer avant la création pour vérifier le calendrier ACRE, ARCE ou maintien de l’ARE.',
        'subject':
            'Objet : rendez-vous création d’entreprise et maintien de mes droits',
        'body': '''Madame, Monsieur,

Je prépare un projet de création d’activité dans le domaine suivant : [activité précise].

Avant toute immatriculation, je souhaite vérifier mon éligibilité à l’ACRE, les conditions de l’ARCE ou du maintien partiel de l’ARE, ainsi que les justificatifs à fournir.

Je vous remercie de me proposer un rendez-vous et de m’indiquer les démarches à effectuer avant la date de création envisagée : [date].

Cordialement,
[Nom, prénom]
[Identifiant France Travail]
[Coordonnées]''',
      });
    }

    if (_journeyMentionsInsurance(journey)) {
      templates.add({
        'title': 'Demande de devis d’assurance professionnelle',
        'use': 'À adresser à plusieurs assureurs avant la première prestation.',
        'subject':
            'Objet : demande de devis pour une assurance professionnelle',
        'body':
            '''Madame, Monsieur,

Je prépare le lancement d’une activité de ${activity.isEmpty ? '[activité précise]' : activity}${region.isEmpty ? '' : ' en $region'}.

Je souhaite recevoir un devis précisant les garanties adaptées à cette activité, les exclusions, les franchises, les plafonds d’indemnisation et la couverture des déplacements, du matériel ou des biens confiés lorsque cela est pertinent.

Date de début envisagée : [date]
Chiffre d’affaires prévisionnel : [montant]
Nombre d’interventions prévu : [nombre]

Merci de m’indiquer les documents nécessaires à l’établissement du contrat.

Cordialement,
[Nom, prénom]
[Coordonnées]''',
      });
    }

    return templates;
  }

  static bool _journeyMentionsInsurance(Map<String, dynamic> journey) {
    final values = <String>[
      ..._expandList(journey['blockingAlerts']),
      ..._mapList(
        journey['regulationTutorial'],
      ).expand((item) => [_text(item['title']), _text(item['description'])]),
      ..._mapList(journey['steps']).expand(
        (item) => [
          _text(item['title']),
          ..._expandList(item['todos']),
          ..._expandList(item['checks']),
        ],
      ),
    ];
    return values.any((value) => _fingerprint(value).contains('assurance'));
  }

  static pw.Widget _letterTemplate(Map<String, dynamic> template) {
    final title = _text(template['title']);
    final use = _text(template['use']);
    final subject = _text(template['subject']);
    final body = _text(template['body']);

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          if (use.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(use, style: pw.TextStyle(fontSize: 8)),
          ],
          if (subject.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              subject,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
          if (body.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              body,
              style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
            ),
          ],
        ],
      ),
    );
  }

  static List<Map<String, String>> _extractSources(
    List<Map<String, dynamic>> items,
  ) {
    final result = <Map<String, String>>[];
    final seen = <String>{};
    final urlPattern = RegExp(r'https?://[^\s]+');

    for (final item in items) {
      final title = _text(
        item['title'] ?? item['label'] ?? item['name'] ?? 'Source officielle',
      );
      final description = _text(
        item['description'] ?? item['text'] ?? item['summary'] ?? item['desc'],
      );
      for (final match in urlPattern.allMatches(description)) {
        var url = match.group(0) ?? '';
        url = url.replaceAll(RegExp(r'[\),.;]+$'), '');
        final key = _fingerprint(url);
        if (url.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        result.add({
          'title': title.toLowerCase().contains('source officielle')
              ? _sourceLabel(url)
              : title,
          'url': url,
        });
      }
    }
    return result;
  }

  static String _sourceLabel(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.replaceFirst('www.', '') ?? '';
    return host.isEmpty ? 'Source officielle' : host;
  }

  static bool _isSourceItem(Map<String, dynamic> item) {
    final title = _fingerprint(
      _text(item['title'] ?? item['label'] ?? item['name']),
    );
    final description = _text(
      item['description'] ?? item['text'] ?? item['summary'] ?? item['desc'],
    );
    return title.contains('source officielle') ||
        description.startsWith('http://') ||
        description.startsWith('https://');
  }

  static pw.Widget _sourceLine(Map<String, String> source) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(bottom: 6),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey50,
      border: pw.Border.all(color: PdfColors.grey200),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          source['title'] ?? 'Source officielle',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(source['url'] ?? '', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );

  static pw.Widget _finalChecklist() => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 12, bottom: 10),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.orange50,
      border: pw.Border.all(color: PdfColors.orange300),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Checklist avant la première prestation',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange800,
          ),
        ),
        pw.SizedBox(height: 6),
        ...const [
          'Les autorisations, qualifications ou accords nécessaires sont obtenus.',
          'L’immatriculation et les justificatifs officiels sont disponibles.',
          'Les assurances adaptées sont actives à la date de début.',
          'Les tarifs, devis, factures et conditions de prestation sont prêts.',
          'Un système de suivi du chiffre d’affaires, des dépenses et des échéances est en place.',
        ].map(_checkLine),
      ],
    ),
  );

  static pw.Widget _legalNotice() => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Text(
      'Ce guide fournit une orientation personnalisée à partir des informations renseignées. Il ne remplace pas la vérification des textes officiels ni, lorsque nécessaire, l’avis d’un professionnel du droit, du chiffre, de l’assurance ou de l’organisme compétent.',
      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    ),
  );

  static pw.Widget _cover(pw.ImageProvider logo, Map<String, dynamic> journey) {
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
              pw.Image(logo, width: 44, height: 44),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _brand(20),
                    pw.Text(
                      'Mon guide personnalisé pas à pas',
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

  static pw.Widget _header(pw.ImageProvider logo) => pw.Row(
    children: [
      pw.Image(logo, width: 22, height: 22),
      pw.SizedBox(width: 8),
      _brand(13),
      pw.Spacer(),
      pw.Text('Guide personnalisé', style: const pw.TextStyle(fontSize: 9)),
    ],
  );

  static pw.Widget _footer(pw.Context context, pw.ImageProvider logo) => pw.Row(
    children: [
      pw.Image(logo, width: 15, height: 15),
      pw.SizedBox(width: 6),
      pw.Text(
        'Document généré par iliprestō',
        style: const pw.TextStyle(fontSize: 8),
      ),
      pw.Spacer(),
      pw.Text(
        'Page ${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8),
      ),
    ],
  );

  static pw.Widget _watermark() => pw.FullPage(
    ignoreMargins: true,
    child: pw.Center(
      child: pw.Transform.rotate(
        angle: -0.55,
        child: pw.Opacity(
          opacity: 0.04,
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

  static pw.Widget _brand(double size) => pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: 'ili',
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange600,
          ),
        ),
        pw.TextSpan(
          text: 'prestō',
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _section(String text) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 12, bottom: 7),
    padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: pw.BoxDecoration(
      color: PdfColors.blue50,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    ),
  );

  static pw.Widget _miniHeading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2, bottom: 5),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
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

  static pw.Widget _checkLine(String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('[ ] ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
          ),
        ),
      ],
    ),
  );

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : const <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList()
      : const <Map<String, dynamic>>[];

  static List<Map<String, dynamic>> _deduplicateItems(
    List<Map<String, dynamic>> items,
  ) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in items) {
      final identity = [
        _text(item['id']),
        _text(item['title'] ?? item['label'] ?? item['name'] ?? item['week']),
        _text(
          item['description'] ??
              item['text'] ??
              item['summary'] ??
              item['desc'] ??
              item['objective'],
        ),
      ].where((value) => value.isNotEmpty).join('|');
      final key = _fingerprint(identity);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(item);
    }
    return result;
  }

  static List<String> _expandList(dynamic value) {
    final result = <String>[];
    for (final raw in _stringList(value)) {
      final normalized = raw
          .replaceAll('•', ';')
          .replaceAll(' · ', ';')
          .replaceAll('\r', '\n');
      final parts = normalized.split(RegExp(r'\s*;\s*|\n+'));
      for (final part in parts) {
        final cleaned = part.trim();
        if (cleaned.isNotEmpty) result.add(cleaned);
      }
    }
    return result;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map(_text).where((item) => item.isNotEmpty).toList();
    }
    final text = _text(value);
    return text.isEmpty ? const <String>[] : <String>[text];
  }

  static List<String> _uniqueStrings(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final cleaned = raw.trim();
      final key = _fingerprint(cleaned);
      if (cleaned.isEmpty || key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(cleaned);
    }
    return result;
  }

  static String _newText(String value, Set<String> seen) {
    final cleaned = value.trim();
    final key = _fingerprint(cleaned);
    if (cleaned.isEmpty || key.isEmpty || seen.contains(key)) return '';
    seen.add(key);
    return cleaned;
  }

  static String _fingerprint(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'https?://[^\s]+'), '')
      .replaceAll(RegExp(r'[^a-z0-9àâäçéèêëîïôöùûüÿœ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _text(dynamic value) => value == null ? '' : '$value'.trim();

  static String _prettyLabel(String raw) {
    if (_labelOverrides.containsKey(raw)) return _labelOverrides[raw]!;
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

  static String _sanitizeFilePart(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
