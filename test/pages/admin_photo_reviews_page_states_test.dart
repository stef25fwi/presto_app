import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_photo_reviews_page.dart';

void main() {
  Map<String, dynamic> review({
    String id = 'review-1',
    String listingId = 'listing-1',
    String title = 'Annonce test',
    Object? createdAt,
    String reason = 'Contrôle automatique',
    String detectedText = '',
    Map<String, dynamic>? safeSearch,
  }) {
    return <String, dynamic>{
      'reviewId': id,
      'listingId': listingId,
      'listingTitle': title,
      'imageUrl': '',
      'thumbnailUrl': '',
      'reason': reason,
      'createdAt': createdAt ?? DateTime.utc(2026, 7, 16, 12),
      'detectedText': detectedText,
      if (safeSearch != null) 'safeSearch': safeSearch,
    };
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required Stream<List<Map<String, dynamic>>> stream,
    AdminPhotoReviewDecision? onDecision,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminPhotoReviewsPage(
          reviewsStream: stream,
          onDecision: onDecision,
        ),
      ),
    );
  }

  Future<void> flushStream(WidgetTester tester) async {
    for (var index = 0; index < 6; index++) {
      await tester.pump();
    }
  }

  testWidgets('affiche le chargement avant la première émission',
      (tester) async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    addTearDown(controller.close);

    await pumpPage(tester, stream: controller.stream);
    await tester.pump();

    expect(find.text('Photos à valider'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Aucune photo en attente de validation.'), findsNothing);
  });

  testWidgets('affiche une erreur de chargement lisible', (tester) async {
    await pumpPage(
      tester,
      stream: Stream<List<Map<String, dynamic>>>.error(
        StateError('indisponible'),
      ),
    );
    await flushStream(tester);

    expect(
      find.text('Impossible de charger les photos à valider.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('affiche l’état vide', (tester) async {
    await pumpPage(
      tester,
      stream: Stream.value(const <Map<String, dynamic>>[]),
    );
    await flushStream(tester);

    expect(
      find.text('Aucune photo en attente de validation.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
  });

  testWidgets('trie et affiche les métadonnées des photos', (tester) async {
    final reviews = <Map<String, dynamic>>[
      review(
        id: 'older',
        listingId: 'listing-old',
        title: '   ',
        createdAt: '2026-07-15T08:00:00.000Z',
        reason: '',
      ),
      review(
        id: 'newer',
        title: 'Annonce récente',
        createdAt: Timestamp.fromDate(DateTime.utc(2026, 7, 16, 18)),
        detectedText: 'NUMÉRO 0590 INTERDIT',
        safeSearch: <String, dynamic>{
          'summary': <String, dynamic>{
            'adult': 'VERY_UNLIKELY',
            'violence': 'UNLIKELY',
          },
        },
      ),
    ];

    await pumpPage(tester, stream: Stream.value(reviews));
    await flushStream(tester);

    expect(find.text('Annonce récente'), findsOneWidget);
    expect(find.text('listing-old'), findsOneWidget);
    expect(find.text('Contrôle automatique'), findsOneWidget);
    expect(find.text('Revue manuelle requise'), findsOneWidget);
    expect(find.text('Texte OCR détecté'), findsOneWidget);
    expect(find.text('NUMÉRO 0590 INTERDIT'), findsOneWidget);
    expect(
      find.text('adult: VERY_UNLIKELY · violence: UNLIKELY'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNWidgets(2));
    expect(find.byType(Dismissible), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Annonce récente')).dy,
      lessThan(tester.getTopLeft(find.text('listing-old')).dy),
    );
  });

  testWidgets('verrouille la carte pendant une acceptation', (tester) async {
    final completer = Completer<void>();
    final calls = <Map<String, String?>>[];

    await pumpPage(
      tester,
      stream: Stream.value(<Map<String, dynamic>>[review()]),
      onDecision: ({required reviewId, required decision, reason}) {
        calls.add(<String, String?>{
          'reviewId': reviewId,
          'decision': decision,
          'reason': reason,
        });
        return completer.future;
      },
    );
    await flushStream(tester);

    final approve = find.widgetWithText(ElevatedButton, 'Accepter');
    await tester.tap(approve);
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single['reviewId'], 'review-1');
    expect(calls.single['decision'], 'approved');
    expect(calls.single['reason'], isNull);
    expect(tester.widget<ElevatedButton>(approve).onPressed, isNull);
    expect(
      find.descendant(
        of: approve,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(approve, warnIfMissed: false);
    await tester.pump();
    expect(calls, hasLength(1));

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Photo acceptée'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(approve).onPressed, isNotNull);
  });

  testWidgets('annule puis confirme un refus détaillé', (tester) async {
    final calls = <Map<String, String?>>[];

    await pumpPage(
      tester,
      stream: Stream.value(<Map<String, dynamic>>[review()]),
      onDecision: ({required reviewId, required decision, reason}) async {
        calls.add(<String, String?>{
          'reviewId': reviewId,
          'decision': decision,
          'reason': reason,
        });
      },
    );
    await flushStream(tester);

    final reject = find.widgetWithText(OutlinedButton, 'Refuser');
    await tester.tap(reject);
    await tester.pumpAndSettle();
    expect(find.text('Motif du refus'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(reject);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autre').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'visage non autorisé');

    final dialog = find.byType(AlertDialog);
    final confirm = find.descendant(
      of: dialog,
      matching: find.widgetWithText(ElevatedButton, 'Refuser'),
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single['decision'], 'rejected');
    expect(calls.single['reason'], 'Autre — visage non autorisé');
    expect(find.text('Photo refusée'), findsOneWidget);
  });

  testWidgets('accepte une photo par balayage vers la droite', (tester) async {
    final calls = <String>[];

    await pumpPage(
      tester,
      stream: Stream.value(<Map<String, dynamic>>[
        review(createdAt: DateTime.utc(2026, 7, 16, 13)),
      ]),
      onDecision: ({required reviewId, required decision, reason}) async {
        calls.add('$reviewId:$decision:${reason ?? '-'}');
      },
    );
    await flushStream(tester);

    await tester.drag(find.byType(Dismissible), const Offset(650, 0));
    await tester.pumpAndSettle();

    expect(calls, <String>['review-1:approved:-']);
    expect(find.text('Photo acceptée'), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);
  });

  testWidgets('affiche le message précis d’une erreur Functions',
      (tester) async {
    await pumpPage(
      tester,
      stream: Stream.value(<Map<String, dynamic>>[review()]),
      onDecision: ({required reviewId, required decision, reason}) async {
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Cette photo ne peut pas être modérée.',
        );
      },
    );
    await flushStream(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Accepter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cette photo ne peut pas être modérée.'),
      findsOneWidget,
    );
  });

  testWidgets('affiche le message générique pour une erreur inattendue',
      (tester) async {
    await pumpPage(
      tester,
      stream: Stream.value(<Map<String, dynamic>>[
        review(id: 'review-error', createdAt: null),
      ]),
      onDecision: ({required reviewId, required decision, reason}) async {
        throw StateError('échec inattendu');
      },
    );
    await flushStream(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Accepter'));
    await tester.pumpAndSettle();

    expect(
      find.text('Impossible de traiter cette photo pour le moment.'),
      findsOneWidget,
    );
  });
}
