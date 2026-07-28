import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_photo_reviews_page.dart';

void main() {
  testWidgets('affiche l’état vide', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPhotoReviewsPage(
          reviewsStream: Stream.value(const <Map<String, dynamic>>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune photo en attente de validation.'), findsOneWidget);
  });

  testWidgets('rend les détails et transmet l’approbation', (tester) async {
    final decisions = <Map<String, Object?>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPhotoReviewsPage(
          reviewsStream: Stream.value(<Map<String, dynamic>>[
            <String, dynamic>{
              '_reviewId': 'review-1',
              'listingId': 'listing-1',
              'listingTitle': 'Photo de plomberie',
              'imageUrl': '',
              'thumbnailUrl': '',
              'reason': '',
              'createdAt': DateTime.utc(2026, 7, 27),
              'detectedText': 'texte détecté',
              'safeSearch': <String, dynamic>{
                'summary': <String, dynamic>{'adult': 'unlikely'},
              },
            },
          ]),
          onDecision: ({
            required String reviewId,
            required String decision,
            String? reason,
          }) async {
            decisions.add(<String, Object?>{
              'reviewId': reviewId,
              'decision': decision,
              'reason': reason,
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Photo de plomberie'), findsOneWidget);
    expect(find.text('Revue manuelle requise'), findsOneWidget);
    expect(find.text('Texte OCR détecté'), findsOneWidget);
    expect(find.text('adult: unlikely'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

    final acceptButton = find.text('Accepter');
    await tester.ensureVisible(acceptButton);
    await tester.pumpAndSettle();
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    expect(decisions, <Map<String, Object?>>[
      <String, Object?>{
        'reviewId': 'review-1',
        'decision': 'approved',
        'reason': null,
      },
    ]);
    expect(find.text('Photo acceptée'), findsOneWidget);
  });
}
