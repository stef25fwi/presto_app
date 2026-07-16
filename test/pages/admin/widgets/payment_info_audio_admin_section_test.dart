import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin/widgets/payment_info_audio_admin_section.dart';
import 'package:presto_app/services/payment_info_audio_service.dart';

void main() {
  PaymentInfoAudioAdminSettings settings({
    String text = '',
    String? draftAudioUrl,
    Timestamp? lastPublishedAt,
  }) {
    return PaymentInfoAudioAdminSettings(
      text: text,
      draftAudioUrl: draftAudioUrl,
      draftStoragePath: null,
      draftContentType: null,
      draftVersion: null,
      draftGeneratedAt: null,
      draftGeneratedBy: null,
      draftVoice: null,
      draftTextHash: null,
      lastGeneratedAt: null,
      lastPublishedAt: lastPublishedAt,
    );
  }

  Widget buildSection({
    required Stream<PaymentInfoAudioAdminSettings> settingsStream,
    PaymentInfoAudioAdminTextSaver? saveAdminText,
    PaymentInfoAudioDraftGenerator? generateDraft,
    PaymentInfoAudioDraftPublisher? publishDraft,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PaymentInfoAudioAdminSection(
            settingsStream: settingsStream,
            saveAdminText: saveAdminText ?? (text) async {},
            generateDraft: generateDraft ??
                ({required String text}) async => settings(text: text),
            publishDraft: publishDraft ?? () async {},
            previewBuilder: ({
              required String audioUrl,
              required VoidCallback onPlayed,
            }) {
              return TextButton(
                onPressed: onPlayed,
                child: Text('Lire $audioUrl'),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('hydrate le texte sauvegardé et affiche la dernière publication',
      (tester) async {
    final publishedAt = Timestamp.fromDate(DateTime(2026, 7, 15, 12, 30));

    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(
          settings(
            text: 'Texte enregistré',
            lastPublishedAt: publishedAt,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Texte enregistré');
    expect(find.textContaining('Dernière publication :'), findsOneWidget);
    expect(find.text('Audio popup « Infos paiement »'), findsOneWidget);
  });

  testWidgets('conserve le texte par défaut lorsque le réglage est vide',
      (tester) async {
    await tester.pumpWidget(
      buildSection(settingsStream: Stream.value(settings())),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, contains('ilipresto.fr'));
    expect(field.controller!.text, contains('paiement traçable'));
  });

  testWidgets('refuse la sauvegarde et la génération d’un texte vide',
      (tester) async {
    var saveCalls = 0;
    var generateCalls = 0;

    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(settings()),
        saveAdminText: (text) async {
          saveCalls += 1;
        },
        generateDraft: ({required String text}) async {
          generateCalls += 1;
          return settings(text: text);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');

    await tester.tap(find.text('Sauvegarder texte'));
    await tester.pump();
    expect(find.text('Le texte audio ne peut pas être vide.'), findsOneWidget);
    expect(saveCalls, 0);

    await tester.tap(find.text('Générer le MP3 depuis ce texte'));
    await tester.pump();
    expect(find.text('Le texte audio ne peut pas être vide.'), findsWidgets);
    expect(generateCalls, 0);
  });

  testWidgets('sauvegarde le texte nettoyé avec un état de chargement',
      (tester) async {
    final completer = Completer<void>();
    String? savedText;

    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(settings()),
        saveAdminText: (text) {
          savedText = text;
          return completer.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Nouveau texte  ');
    await tester.tap(find.text('Sauvegarder texte'));
    await tester.pump();

    expect(savedText, 'Nouveau texte');
    expect(find.text('Sauvegarde...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();

    expect(
      find.text('Texte sauvegardé. Tu peux maintenant générer le MP3.'),
      findsOneWidget,
    );
    expect(find.text('Sauvegarder texte'), findsOneWidget);
  });

  testWidgets('affiche une erreur lorsque la sauvegarde échoue', (tester) async {
    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(settings()),
        saveAdminText: (text) async {
          throw StateError('écriture refusée');
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Texte valide 123');
    await tester.tap(find.text('Sauvegarder texte'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sauvegarde impossible'), findsOneWidget);
    expect(find.textContaining('écriture refusée'), findsOneWidget);
  });

  testWidgets('génère un brouillon après avoir sauvegardé le texte',
      (tester) async {
    final generateCompleter = Completer<PaymentInfoAudioAdminSettings>();
    final savedValues = <String>[];
    String? generatedText;

    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(settings()),
        saveAdminText: (text) async {
          savedValues.add(text);
        },
        generateDraft: ({required String text}) {
          generatedText = text;
          return generateCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Audio sécurisé  ');
    await tester.tap(find.text('Générer le MP3 depuis ce texte'));
    await tester.pump();

    expect(savedValues, ['Audio sécurisé']);
    expect(generatedText, 'Audio sécurisé');
    expect(find.text('Génération MP3...'), findsOneWidget);
    expect(find.text('Conversion du texte en MP3...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    generateCompleter.complete(
      settings(
        text: 'Audio sécurisé',
        draftAudioUrl: 'https://example.test/draft.mp3',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('MP3 brouillon généré. Pré-écoute-le avant validation.'),
      findsOneWidget,
    );
    expect(find.text('Pré-écoute du MP3 brouillon'), findsOneWidget);
    expect(
      find.text('Lire https://example.test/draft.mp3'),
      findsOneWidget,
    );
  });

  testWidgets('affiche une erreur lorsque la génération échoue', (tester) async {
    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(settings()),
        generateDraft: ({required String text}) async {
          throw StateError('service TTS indisponible');
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Texte génération');
    await tester.tap(find.text('Générer le MP3 depuis ce texte'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Génération MP3 impossible'), findsOneWidget);
    expect(find.textContaining('service TTS indisponible'), findsOneWidget);
  });

  testWidgets('bloque la publication avant la pré-écoute puis publie',
      (tester) async {
    final publishCompleter = Completer<void>();
    var publishCalls = 0;

    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(
          settings(draftAudioUrl: 'https://example.test/draft.mp3'),
        ),
        publishDraft: () {
          publishCalls += 1;
          return publishCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Valider et publier le MP3'));
    await tester.pump();
    expect(
      find.text(
        'Pré-écoute obligatoire : écoute le MP3 avant de le publier.',
      ),
      findsOneWidget,
    );
    expect(publishCalls, 0);

    await tester.tap(find.text('Lire https://example.test/draft.mp3'));
    await tester.pump();
    expect(find.text('Pré-écoute confirmée'), findsOneWidget);
    expect(
      find.text('Validation bloquée tant que la pré-écoute n’est pas confirmée.'),
      findsNothing,
    );

    await tester.tap(find.text('Valider et publier le MP3'));
    await tester.pump();
    expect(publishCalls, 1);
    expect(find.text('Publication...'), findsOneWidget);

    publishCompleter.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('MP3 Infos paiement validé et publié dans le popup.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche une erreur lorsque la publication échoue',
      (tester) async {
    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(
          settings(draftAudioUrl: 'https://example.test/error.mp3'),
        ),
        publishDraft: () async {
          throw StateError('publication refusée');
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('J’ai pré-écouté ce MP3'));
    await tester.pump();
    await tester.tap(find.text('Valider et publier le MP3'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Publication impossible'), findsOneWidget);
    expect(find.textContaining('publication refusée'), findsOneWidget);
  });

  testWidgets('modifier le texte annule une pré-écoute confirmée',
      (tester) async {
    await tester.pumpWidget(
      buildSection(
        settingsStream: Stream.value(
          settings(draftAudioUrl: 'https://example.test/preview.mp3'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('J’ai pré-écouté ce MP3'));
    await tester.pump();
    expect(find.text('Pré-écoute confirmée'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Texte modifié');
    await tester.pump();

    expect(find.text('J’ai pré-écouté ce MP3'), findsOneWidget);
    expect(
      find.text('Validation bloquée tant que la pré-écoute n’est pas confirmée.'),
      findsOneWidget,
    );
  });
}
