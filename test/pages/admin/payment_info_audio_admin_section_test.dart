import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin/widgets/payment_info_audio_admin_section.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

class _AudioAdminBackend {
  _AudioAdminBackend(this.firestore);

  final FakeFirebaseFirestore firestore;
  Object? saveError;
  Object? generateError;
  Object? publishError;
  Completer<void>? saveCompleter;
  Completer<void>? generateCompleter;
  Completer<void>? publishCompleter;
  final List<String> savedTexts = <String>[];
  final List<String> generatedTexts = <String>[];
  var publishCalls = 0;

  Future<void> saveText(String text) async {
    savedTexts.add(text);
    final error = saveError;
    if (error != null) throw error;
    final completer = saveCompleter;
    if (completer != null) await completer.future;
  }

  Future<void> call(String name, Map<String, dynamic> parameters) async {
    if (name == 'generatePaymentInfoAudioDraft') {
      generatedTexts.add(parameters['text']?.toString() ?? '');
      final error = generateError;
      if (error != null) throw error;
      final completer = generateCompleter;
      if (completer != null) await completer.future;
      await firestore.collection('admin_settings').doc('payment_info_audio').set(
        <String, dynamic>{
          'draftAudioUrl': 'https://cdn.test/draft.mp3',
          'draftStoragePath': 'drafts/payment.mp3',
          'draftContentType': 'audio/mpeg',
          'draftVersion': 2,
          'draftGeneratedAt': Timestamp(20, 0),
          'draftGeneratedBy': 'admin-1',
          'draftVoice': 'alloy',
          'draftTextHash': 'hash',
          'lastGeneratedAt': Timestamp(20, 0),
        },
        SetOptions(merge: true),
      );
      return;
    }

    if (name == 'publishPaymentInfoAudioDraft') {
      publishCalls += 1;
      final error = publishError;
      if (error != null) throw error;
      final completer = publishCompleter;
      if (completer != null) await completer.future;
      await firestore.collection('public_config').doc('payment_info_audio').set(
        <String, dynamic>{
          'enabled': true,
          'audioUrl': 'https://cdn.test/draft.mp3',
          'contentType': 'audio/mpeg',
          'version': 2,
          'generatedAt': Timestamp(30, 0),
        },
      );
    }
  }
}

Future<void> _seedSettings(
  FakeFirebaseFirestore firestore, {
  String text = '',
  String? draftAudioUrl,
  Timestamp? lastPublishedAt,
}) {
  return firestore.collection('admin_settings').doc('payment_info_audio').set(
    <String, dynamic>{
      'text': text,
      if (draftAudioUrl != null) ...<String, dynamic>{
        'draftAudioUrl': draftAudioUrl,
        'draftStoragePath': 'drafts/payment.mp3',
        'draftContentType': 'audio/mpeg',
        'draftVersion': 1,
        'draftGeneratedAt': Timestamp(10, 0),
        'draftGeneratedBy': 'admin-1',
        'draftVoice': 'alloy',
        'draftTextHash': 'hash',
        'lastGeneratedAt': Timestamp(10, 0),
      },
      if (lastPublishedAt != null) 'lastPublishedAt': lastPublishedAt,
    },
  );
}

Widget _app() {
  return const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: PaymentInfoAudioAdminSection(),
      ),
    ),
  );
}

Future<void> _pumpSection(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pump();
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void _clearSnackBars(WidgetTester tester) {
  ScaffoldMessenger.of(
    tester.element(find.byType(PaymentInfoAudioAdminSection)),
  ).clearSnackBars();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late _AudioAdminBackend backend;

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1000, 1800);
    view.devicePixelRatio = 1;

    firestore = FakeFirebaseFirestore();
    backend = _AudioAdminBackend(firestore);
    PaymentInfoAudioService.setFirestoreForTesting(firestore);
    PaymentInfoAudioService.setCallableForTesting(backend.call);
    PaymentInfoAudioService.setTextSaverForTesting(backend.saveText);
  });

  tearDown(() {
    PaymentInfoAudioService.setFirestoreForTesting(null);
    PaymentInfoAudioService.setCallableForTesting(null);
    PaymentInfoAudioService.setTextSaverForTesting(null);

    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('affiche le texte par défaut puis hydrate le texte sauvegardé',
      (tester) async {
    await _seedSettings(
      firestore,
      text: '  Texte administrateur sauvegardé  ',
    );

    await _pumpSection(tester);

    expect(find.text('Audio popup « Infos paiement »'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Texte administrateur sauvegardé');
    expect(find.text('Pré-écoute du MP3 brouillon'), findsNothing);
  });

  testWidgets('conserve le texte par défaut quand les réglages sont vides',
      (tester) async {
    await _seedSettings(firestore);

    await _pumpSection(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, contains('ilipresto.fr est un outil'));
  });

  testWidgets('refuse sauvegarde et génération quand le texte est vide',
      (tester) async {
    await _seedSettings(firestore);
    await _pumpSection(tester);
    await tester.enterText(find.byType(TextField), '   ');

    await _tapText(tester, 'Sauvegarder texte');
    expect(find.text('Le texte audio ne peut pas être vide.'), findsOneWidget);
    expect(backend.savedTexts, isEmpty);

    _clearSnackBars(tester);
    await tester.pump();

    await _tapText(tester, 'Générer le MP3 depuis ce texte');
    expect(find.text('Le texte audio ne peut pas être vide.'), findsOneWidget);
    expect(backend.generatedTexts, isEmpty);
  });

  testWidgets('sauvegarde un texte nettoyé et affiche le succès',
      (tester) async {
    await _seedSettings(firestore);
    await _pumpSection(tester);
    await tester.enterText(find.byType(TextField), '  Nouveau texte audio  ');

    await _tapText(tester, 'Sauvegarder texte');
    await tester.pump();

    expect(backend.savedTexts, <String>['Nouveau texte audio']);
    expect(
      find.text('Texte sauvegardé. Tu peux maintenant générer le MP3.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche l état de sauvegarde puis traduit une erreur',
      (tester) async {
    await _seedSettings(firestore, text: 'Texte actuel');
    backend.saveCompleter = Completer<void>();
    await _pumpSection(tester);

    await _tapText(tester, 'Sauvegarder texte');
    expect(find.text('Sauvegarde...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    backend.saveCompleter!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Sauvegarder texte'), findsOneWidget);

    _clearSnackBars(tester);
    await tester.pump();
    backend
      ..saveCompleter = null
      ..saveError = StateError('accès refusé');
    await _tapText(tester, 'Sauvegarder texte');
    await tester.pump();
    expect(
      find.textContaining('Sauvegarde impossible : Bad state: accès refusé'),
      findsOneWidget,
    );
  });

  testWidgets('génère un brouillon et rend la pré écoute disponible',
      (tester) async {
    await _seedSettings(firestore);
    await _pumpSection(tester);
    await tester.enterText(find.byType(TextField), '  Texte à convertir  ');

    await _tapText(tester, 'Générer le MP3 depuis ce texte');
    await tester.pump();

    expect(backend.savedTexts, <String>['Texte à convertir']);
    expect(backend.generatedTexts, <String>['Texte à convertir']);
    expect(find.text('Pré-écoute du MP3 brouillon'), findsOneWidget);
    expect(find.text('Pré-écouter le MP3'), findsOneWidget);
    expect(
      find.text('MP3 brouillon généré. Pré-écoute-le avant validation.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Validation bloquée tant que la pré-écoute n’est pas confirmée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('affiche la progression de génération puis son erreur',
      (tester) async {
    await _seedSettings(firestore, text: 'Texte actuel');
    backend.generateCompleter = Completer<void>();
    await _pumpSection(tester);

    await _tapText(tester, 'Générer le MP3 depuis ce texte');
    expect(find.text('Génération MP3...'), findsOneWidget);
    expect(find.text('Conversion du texte en MP3...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    backend.generateCompleter!.complete();
    await tester.pump();
    await tester.pump();

    _clearSnackBars(tester);
    await tester.pump();
    backend
      ..generateCompleter = null
      ..generateError = StateError('service indisponible');
    await _tapText(tester, 'Générer le MP3 depuis ce texte');
    await tester.pump();
    expect(
      find.textContaining(
        'Génération MP3 impossible : Bad state: service indisponible',
      ),
      findsOneWidget,
    );
  });

  testWidgets('bloque la publication avant pré écoute puis publie avec succès',
      (tester) async {
    await _seedSettings(
      firestore,
      text: 'Texte actuel',
      draftAudioUrl: 'https://cdn.test/draft.mp3',
    );
    await _pumpSection(tester);

    await _tapText(tester, 'Valider et publier le MP3');
    expect(backend.publishCalls, 0);
    expect(
      find.text('Pré-écoute obligatoire : écoute le MP3 avant de le publier.'),
      findsOneWidget,
    );

    _clearSnackBars(tester);
    await tester.pump();
    await _tapText(tester, 'J’ai pré-écouté ce MP3');
    expect(find.text('Pré-écoute confirmée'), findsOneWidget);
    expect(
      find.text(
        'Validation bloquée tant que la pré-écoute n’est pas confirmée.',
      ),
      findsNothing,
    );

    await _tapText(tester, 'Valider et publier le MP3');
    await tester.pump();
    expect(backend.publishCalls, 1);
    expect(
      find.text('MP3 Infos paiement validé et publié dans le popup.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche la progression de publication puis son erreur',
      (tester) async {
    await _seedSettings(
      firestore,
      text: 'Texte actuel',
      draftAudioUrl: 'https://cdn.test/draft.mp3',
    );
    backend.publishCompleter = Completer<void>();
    await _pumpSection(tester);

    await _tapText(tester, 'J’ai pré-écouté ce MP3');
    await _tapText(tester, 'Valider et publier le MP3');
    expect(find.text('Publication...'), findsOneWidget);

    backend.publishCompleter!.complete();
    await tester.pump();
    await tester.pump();

    _clearSnackBars(tester);
    await tester.pump();
    backend
      ..publishCompleter = null
      ..publishError = StateError('publication refusée');
    await _tapText(tester, 'Valider et publier le MP3');
    await tester.pump();
    expect(
      find.textContaining(
        'Publication impossible : Bad state: publication refusée',
      ),
      findsOneWidget,
    );
  });

  testWidgets('modifier le texte annule la confirmation de pré écoute',
      (tester) async {
    await _seedSettings(
      firestore,
      text: 'Texte actuel',
      draftAudioUrl: 'https://cdn.test/draft.mp3',
    );
    await _pumpSection(tester);

    await _tapText(tester, 'J’ai pré-écouté ce MP3');
    expect(find.text('Pré-écoute confirmée'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Texte modifié');
    await tester.pump();
    expect(find.text('J’ai pré-écouté ce MP3'), findsOneWidget);
    expect(
      find.text(
        'Validation bloquée tant que la pré-écoute n’est pas confirmée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('affiche la date de la dernière publication', (tester) async {
    await _seedSettings(
      firestore,
      text: 'Texte actuel',
      lastPublishedAt: Timestamp.fromDate(DateTime(2026, 7, 15, 12, 30)),
    );

    await _pumpSection(tester);

    expect(find.textContaining('Dernière publication :'), findsOneWidget);
    expect(find.textContaining('2026-07-15'), findsOneWidget);
  });
}
