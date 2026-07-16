import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin/widgets/payment_info_audio_admin_section.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

PaymentInfoAudioAdminSettings _settings({
  String text = '',
  String? draftAudioUrl,
  Timestamp? lastPublishedAt,
}) {
  return PaymentInfoAudioAdminSettings(
    text: text,
    draftAudioUrl: draftAudioUrl,
    draftStoragePath: draftAudioUrl == null ? null : 'drafts/payment.mp3',
    draftContentType: draftAudioUrl == null ? null : 'audio/mpeg',
    draftVersion: draftAudioUrl == null ? null : 2,
    draftGeneratedAt: draftAudioUrl == null ? null : Timestamp(20, 0),
    draftGeneratedBy: draftAudioUrl == null ? null : 'admin-1',
    draftVoice: draftAudioUrl == null ? null : 'alloy',
    draftTextHash: draftAudioUrl == null ? null : 'hash',
    lastGeneratedAt: draftAudioUrl == null ? null : Timestamp(20, 0),
    lastPublishedAt: lastPublishedAt,
  );
}

class _FakePaymentInfoAudioService extends PaymentInfoAudioService {
  _FakePaymentInfoAudioService({PaymentInfoAudioAdminSettings? initialSettings})
      : watchSettings = initialSettings ?? _settings(),
        generatedSettings = initialSettings ?? _settings(),
        super(firestore: FakeFirebaseFirestore());

  PaymentInfoAudioAdminSettings watchSettings;
  PaymentInfoAudioAdminSettings generatedSettings;
  Object? saveError;
  Object? generateError;
  Object? publishError;
  Completer<void>? saveCompleter;
  Completer<PaymentInfoAudioAdminSettings>? generateCompleter;
  Completer<PaymentInfoAudioConfig?>? publishCompleter;
  final List<String> savedTexts = <String>[];
  final List<String> generatedTexts = <String>[];
  var publishCalls = 0;

  @override
  Stream<PaymentInfoAudioAdminSettings> watchAdminSettings() {
    return Stream<PaymentInfoAudioAdminSettings>.value(watchSettings);
  }

  @override
  Future<void> saveAdminText(String text) async {
    savedTexts.add(text);
    final error = saveError;
    if (error != null) throw error;
    final completer = saveCompleter;
    if (completer != null) await completer.future;
  }

  @override
  Future<PaymentInfoAudioAdminSettings> generatePaymentInfoAudioDraft({
    required String text,
    String voice = 'alloy',
    String locale = 'fr-FR',
  }) async {
    generatedTexts.add(text);
    final error = generateError;
    if (error != null) throw error;
    final completer = generateCompleter;
    if (completer != null) return completer.future;
    return generatedSettings;
  }

  @override
  Future<PaymentInfoAudioConfig?> publishPaymentInfoAudioDraft() async {
    publishCalls += 1;
    final error = publishError;
    if (error != null) throw error;
    final completer = publishCompleter;
    if (completer != null) return completer.future;
    return null;
  }
}

Widget _app(_FakePaymentInfoAudioService service) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: PaymentInfoAudioAdminSection(
          service: service,
          playerBuilder: ({
            required String audioUrl,
            required String label,
            required VoidCallback onPlayed,
          }) {
            return ElevatedButton(
              key: const Key('fake-audio-player'),
              onPressed: onPlayed,
              child: Text('$label — $audioUrl'),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _pumpSection(
  WidgetTester tester,
  _FakePaymentInfoAudioService service,
) async {
  await tester.pumpWidget(_app(service));
  await tester.pump();
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1000, 1800);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('affiche le texte par défaut puis hydrate le texte sauvegardé',
      (tester) async {
    final service = _FakePaymentInfoAudioService(
      initialSettings: _settings(text: '  Texte administrateur sauvegardé  '),
    );

    await _pumpSection(tester, service);

    expect(find.text('Audio popup « Infos paiement »'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Texte administrateur sauvegardé');
    expect(find.text('Pré-écoute du MP3 brouillon'), findsNothing);
  });

  testWidgets('conserve le texte par défaut quand les réglages sont vides',
      (tester) async {
    final service = _FakePaymentInfoAudioService();

    await _pumpSection(tester, service);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, contains('ilipresto.fr est un outil'));
  });

  testWidgets('refuse sauvegarde et génération quand le texte est vide',
      (tester) async {
    final service = _FakePaymentInfoAudioService();
    await _pumpSection(tester, service);
    await tester.enterText(find.byType(TextField), '   ');

    await _tapText(tester, 'Sauvegarder texte');
    expect(find.text('Le texte audio ne peut pas être vide.'), findsOneWidget);
    expect(service.savedTexts, isEmpty);

    ScaffoldMessenger.of(
      tester.element(find.byType(PaymentInfoAudioAdminSection)),
    ).clearSnackBars();
    await tester.pump();

    await _tapText(tester, 'Générer le MP3 depuis ce texte');
    expect(find.text('Le texte audio ne peut pas être vide.'), findsOneWidget);
    expect(service.generatedTexts, isEmpty);
  });

  testWidgets('sauvegarde un texte nettoyé et affiche le succès',
      (tester) async {
    final service = _FakePaymentInfoAudioService();
    await _pumpSection(tester, service);
    await tester.enterText(find.byType(TextField), '  Nouveau texte audio  ');

    await _tapText(tester, 'Sauvegarder texte');
    await tester.pump();

    expect(service.savedTexts, <String>['Nouveau texte audio']);
    expect(
      find.text('Texte sauvegardé. Tu peux maintenant générer le MP3.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche l état de sauvegarde puis traduit une erreur',
      (tester) async {
    final service = _FakePaymentInfoAudioService()
      ..saveCompleter = Completer<void>();
    await _pumpSection(tester, service);

    await _tapText(tester, 'Sauvegarder texte');
    expect(find.text('Sauvegarde...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.saveCompleter!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Sauvegarder texte'), findsOneWidget);

    service
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
    final service = _FakePaymentInfoAudioService()
      ..generatedSettings = _settings(
        text: 'Texte généré',
        draftAudioUrl: 'https://cdn.test/draft.mp3',
      );
    await _pumpSection(tester, service);
    await tester.enterText(find.byType(TextField), '  Texte à convertir  ');

    await _tapText(tester, 'Générer le MP3 depuis ce texte');
    await tester.pump();

    expect(service.savedTexts, <String>['Texte à convertir']);
    expect(service.generatedTexts, <String>['Texte à convertir']);
    expect(find.text('Pré-écoute du MP3 brouillon'), findsOneWidget);
    expect(find.byKey(const Key('fake-audio-player')), findsOneWidget);
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
    final completer = Completer<PaymentInfoAudioAdminSettings>();
    final service = _FakePaymentInfoAudioService()
      ..generateCompleter = completer;
    await _pumpSection(tester, service);

    await _tapText(tester, 'Générer le MP3 depuis ce texte');
    expect(find.text('Génération MP3...'), findsOneWidget);
    expect(find.text('Conversion du texte en MP3...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    completer.complete(_settings());
    await tester.pump();
    await tester.pump();

    service
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
    final service = _FakePaymentInfoAudioService(
      initialSettings: _settings(
        text: 'Texte actuel',
        draftAudioUrl: 'https://cdn.test/draft.mp3',
      ),
    );
    await _pumpSection(tester, service);

    await _tapText(tester, 'Valider et publier le MP3');
    expect(service.publishCalls, 0);
    expect(
      find.text('Pré-écoute obligatoire : écoute le MP3 avant de le publier.'),
      findsOneWidget,
    );

    ScaffoldMessenger.of(
      tester.element(find.byType(PaymentInfoAudioAdminSection)),
    ).clearSnackBars();
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('fake-audio-player')));
    await tester.tap(find.byKey(const Key('fake-audio-player')));
    await tester.pump();
    expect(find.text('Pré-écoute confirmée'), findsOneWidget);
    expect(
      find.text(
        'Validation bloquée tant que la pré-écoute n’est pas confirmée.',
      ),
      findsNothing,
    );

    await _tapText(tester, 'Valider et publier le MP3');
    await tester.pump();
    expect(service.publishCalls, 1);
    expect(
      find.text('MP3 Infos paiement validé et publié dans le popup.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche la progression de publication puis son erreur',
      (tester) async {
    final completer = Completer<PaymentInfoAudioConfig?>();
    final service = _FakePaymentInfoAudioService(
      initialSettings: _settings(
        text: 'Texte actuel',
        draftAudioUrl: 'https://cdn.test/draft.mp3',
      ),
    )..publishCompleter = completer;
    await _pumpSection(tester, service);

    await _tapText(tester, 'J’ai pré-écouté ce MP3');
    await _tapText(tester, 'Valider et publier le MP3');
    expect(find.text('Publication...'), findsOneWidget);

    completer.complete(null);
    await tester.pump();
    await tester.pump();

    service
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
    final service = _FakePaymentInfoAudioService(
      initialSettings: _settings(
        text: 'Texte actuel',
        draftAudioUrl: 'https://cdn.test/draft.mp3',
      ),
    );
    await _pumpSection(tester, service);

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
    final service = _FakePaymentInfoAudioService(
      initialSettings: _settings(
        text: 'Texte actuel',
        lastPublishedAt: Timestamp.fromDate(DateTime(2026, 7, 15, 12, 30)),
      ),
    );

    await _pumpSection(tester, service);

    expect(find.textContaining('Dernière publication :'), findsOneWidget);
    expect(find.textContaining('2026-07-15'), findsOneWidget);
  });
}
