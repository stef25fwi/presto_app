import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/trust_score/trust_score_models.dart';
import 'package:presto_app/features/trust_score/trust_score_service.dart';
import 'package:presto_app/features/trust_score/trust_score_widgets.dart';

class _NullAuthPlatform extends FirebaseAuthPlatform {
  _NullAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;
}

class _FakeTrustScoreService implements TrustScoreService {
  Future<List<EligibleResponderForReview>> respondersFuture =
      Future<List<EligibleResponderForReview>>.value(
    const <EligibleResponderForReview>[],
  );
  Future<TrustScoreProfile> profileFuture = Future<TrustScoreProfile>.value(
    TrustScoreProfile(
      summary: TrustScoreSummary.empty(),
      latestReviews: const <VerifiedReviewPreview>[],
      ratingsPaidShowcaseEnabled: false,
    ),
  );
  bool throwOnSubmit = false;
  int profileCalls = 0;
  int submitCalls = 0;
  int reportCalls = 0;
  int replyCalls = 0;
  String? submittedComment;
  String? reportedReason;
  String? reportedDetails;
  String? submittedReply;

  @override
  Future<void> closeOfferWithReason({
    required String offerId,
    required String reason,
    bool jobDone = false,
  }) async {}

  @override
  Future<List<EligibleResponderForReview>> getEligibleRespondersForReview({
    required String offerId,
  }) =>
      respondersFuture;

  @override
  Future<SubmitReviewResult> submitVerifiedReview({
    required String offerId,
    required String reviewedUserId,
    required int communicationRating,
    required int punctualityRating,
    required int qualityRating,
    required String comment,
    required bool confirmationChecked,
  }) async {
    submitCalls++;
    submittedComment = comment;
    if (throwOnSubmit) throw StateError('submit failed');
    return const SubmitReviewResult(
      reviewId: 'review-1',
      status: 'published',
      averageRating: 5,
    );
  }

  @override
  Future<SubmitReviewResult> submitMutualVerifiedReview({
    required String offerId,
    required String reviewedUserId,
    required String reviewerRole,
    required String reviewedRole,
    required Map<String, int> criteria,
    required String comment,
    required bool confirmationChecked,
    bool? wouldRecommend,
    String privateFeedback = '',
  }) async {
    return const SubmitReviewResult(
      reviewId: 'review-mutual',
      status: 'pending_moderation',
      averageRating: 4,
    );
  }

  @override
  Future<TrustScoreProfile> getUserTrustScore({required String userId}) {
    profileCalls++;
    return profileFuture;
  }

  @override
  Future<Map<String, dynamic>> getUserTrustScoreV2({
    required String userId,
  }) async =>
      <String, dynamic>{};

  @override
  Future<void> reportReview({
    required String reviewId,
    required String reason,
    String details = '',
  }) async {
    reportCalls++;
    reportedReason = reason;
    reportedDetails = details;
  }

  @override
  Future<String> replyToReview({
    required String reviewId,
    required String replyText,
  }) async {
    replyCalls++;
    submittedReply = replyText;
    return 'pending_moderation';
  }
}

const _responder = EligibleResponderForReview(
  userId: 'user-2',
  pseudo: 'Alice',
  city: 'Pointe-à-Pitre',
  photoUrl: null,
  responseAt: null,
  conversationId: 'conversation-1',
);

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

Widget _launcher({
  required Future<dynamic> Function(BuildContext context) open,
  required ValueChanged<dynamic> onResult,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => onResult(await open(context)),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
}

TrustScoreProfile _profile({bool published = false}) {
  return TrustScoreProfile(
    summary: published
        ? const TrustScoreSummary(
            average: 4.6,
            communicationAverage: 4.8,
            punctualityAverage: 4.4,
            qualityAverage: 4.7,
            reviewsCount: 3,
            publishedReviewsCount: 2,
            pendingReviewsCount: 1,
            badges: <String>['top_provider', 'punctual'],
            paidShowcaseActive: false,
          )
        : TrustScoreSummary.empty(),
    latestReviews: const <VerifiedReviewPreview>[],
    ratingsPaidShowcaseEnabled: false,
  );
}

Future<void> _completeRatingsAndConfirmation(
  WidgetTester tester,
  int value,
) async {
  final inputs =
      tester.widgetList<StarRatingInput>(find.byType(StarRatingInput)).toList();
  expect(inputs, hasLength(3));
  for (final input in inputs) {
    input.onChanged(value);
  }
  await tester.pump();
  final checkbox =
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
  checkbox.onChanged!(true);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _NullAuthPlatform();
    FirebaseAuth.instance;
  });

  testWidgets('close reason dialog enables continue after a selection',
      (tester) async {
    dynamic result;
    await tester.pumpWidget(
      _launcher(
        open: (context) => showDialog<String>(
          context: context,
          builder: (_) => const CloseOfferReasonDialog(),
        ),
        onResult: (value) => result = value,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(
      find.text('Pourquoi souhaitez-vous supprimer cette annonce ?'),
      findsOneWidget,
    );
    final disabled = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continuer'),
    );
    expect(disabled.onPressed, isNull);

    await tester.tap(find.text('Je n’ai plus besoin'));
    await tester.pump();
    final enabled = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continuer'),
    );
    expect(enabled.onPressed, isNotNull);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(result, 'Je n’ai plus besoin');
  });

  testWidgets('close reason dialog can be cancelled', (tester) async {
    dynamic result = 'unchanged';
    await tester.pumpWidget(
      _launcher(
        open: (context) => showDialog<String>(
          context: context,
          builder: (_) => const CloseOfferReasonDialog(),
        ),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('found someone dialog returns each supported action',
      (tester) async {
    final cases = <String, FoundSomeoneOnIliPrestoAction>{
      'Supprimer l’annonce sans avis':
          FoundSomeoneOnIliPrestoAction.deleteWithoutReview,
      'Noter plus tard': FoundSomeoneOnIliPrestoAction.rateLater,
      'Rechercher un utilisateur': FoundSomeoneOnIliPrestoAction.searchUser,
    };

    for (final entry in cases.entries) {
      dynamic result;
      await tester.pumpWidget(
        _launcher(
          open: (context) => showDialog<FoundSomeoneOnIliPrestoAction>(
            context: context,
            builder: (_) => const FoundSomeoneOnIliPrestoDialog(),
          ),
          onResult: (value) => result = value,
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vous avez trouvé quelqu’un sur iliprestō ?'),
        findsOneWidget,
      );
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(result, entry.value);
    }
  });

  testWidgets('eligible responder search loads, filters and returns a result',
      (tester) async {
    final service = _FakeTrustScoreService()
      ..respondersFuture = Future<List<EligibleResponderForReview>>.value(
        const <EligibleResponderForReview>[
          _responder,
          EligibleResponderForReview(
            userId: 'user-3',
            pseudo: 'Bob',
            city: 'Les Abymes',
            photoUrl: null,
            responseAt: null,
            conversationId: 'conversation-2',
          ),
        ],
      );
    dynamic result;

    await tester.pumpWidget(
      _launcher(
        open: (context) => showModalBottomSheet<EligibleResponderForReview>(
          context: context,
          isScrollControlled: true,
          builder: (_) => EligibleResponderSearchSheet(
            offerId: 'offer-1',
            service: service,
          ),
        ),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pointe');
    await tester.pump();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(result, same(_responder));
  });

  testWidgets('eligible responder search renders error and empty states',
      (tester) async {
    final errorCompleter = Completer<List<EligibleResponderForReview>>();
    final errorService = _FakeTrustScoreService()
      ..respondersFuture = errorCompleter.future;
    await tester.pumpWidget(
      _host(
        EligibleResponderSearchSheet(
          offerId: 'offer-error',
          service: errorService,
        ),
      ),
    );
    await tester.pump();
    errorCompleter.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger les répondants.'), findsOneWidget);

    final emptyService = _FakeTrustScoreService();
    await tester.pumpWidget(
      _host(
        EligibleResponderSearchSheet(
          key: const ValueKey<String>('empty-sheet'),
          offerId: 'offer-empty',
          service: emptyService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun utilisateur trouvé'), findsOneWidget);
  });

  testWidgets('star rating input exposes semantics and forwards the value',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _host(
        StarRatingInput(
          label: 'Communication',
          helperText: 'Clarté des échanges',
          value: null,
          onChanged: (value) => selected = value,
        ),
      ),
    );

    expect(find.text('Communication'), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(5));
    await tester.tap(find.byTooltip('4 sur 5'));
    expect(selected, 4);

    await tester.pumpWidget(
      _host(
        StarRatingInput(
          label: 'Communication',
          helperText: 'Clarté des échanges',
          value: 3,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border_rounded), findsNWidgets(2));
  });

  testWidgets('review form submits a complete verified review', (tester) async {
    final service = _FakeTrustScoreService();
    dynamic result;
    await tester.pumpWidget(
      _launcher(
        open: (context) => showDialog<SubmitReviewResult>(
          context: context,
          builder: (_) => ReviewFormDialog(
            offerId: 'offer-1',
            offerTitle: 'Besoin de ménage',
            responder: _responder,
            service: service,
          ),
        ),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final initiallyDisabled = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Publier l’avis'),
    );
    expect(initiallyDisabled.onPressed, isNull);

    await _completeRatingsAndConfirmation(tester, 5);
    await tester.enterText(find.byType(TextField), 'Très bonne prestation');
    await tester.pump();
    await tester.ensureVisible(find.text('Publier l’avis'));
    await tester.tap(find.text('Publier l’avis'));
    await tester.pumpAndSettle();

    expect(service.submitCalls, 1);
    expect(service.submittedComment, 'Très bonne prestation');
    expect(result, isA<SubmitReviewResult>());
    expect((result as SubmitReviewResult).isPublished, isTrue);
  });

  testWidgets('review form displays submit failure and supports rate later',
      (tester) async {
    final service = _FakeTrustScoreService()..throwOnSubmit = true;
    dynamic result;
    await tester.pumpWidget(
      _launcher(
        open: (context) => showDialog<SubmitReviewResult>(
          context: context,
          builder: (_) => ReviewFormDialog(
            offerId: 'offer-2',
            offerTitle: 'Jardinage',
            responder: _responder,
            service: service,
          ),
        ),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await _completeRatingsAndConfirmation(tester, 4);
    await tester.ensureVisible(find.text('Publier l’avis'));
    await tester.tap(find.text('Publier l’avis'));
    await tester.pumpAndSettle();
    expect(
      find.text('Impossible d’enregistrer cet avis pour le moment.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Noter plus tard'));
    await tester.tap(find.text('Noter plus tard'));
    await tester.pumpAndSettle();
    expect((result as SubmitReviewResult).isRateLater, isTrue);
  });

  testWidgets('report dialog requires a reason and submits details',
      (tester) async {
    final service = _FakeTrustScoreService();
    dynamic result;
    await tester.pumpWidget(
      _launcher(
        open: (context) => showDialog<bool>(
          context: context,
          builder: (_) => ReviewReportDialog(
            reviewId: 'review-1',
            service: service,
          ),
        ),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    final disabled = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Signaler'),
    );
    expect(disabled.onPressed, isNull);

    await tester.tap(find.text('Avis mensonger'));
    await tester.enterText(find.byType(TextField), 'Expérience inconnue');
    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();
    expect(service.reportCalls, 1);
    expect(service.reportedReason, 'Avis mensonger');
    expect(service.reportedDetails, 'Expérience inconnue');
    expect(result, isTrue);
  });

  testWidgets('reply dialog ignores empty text then submits a reply',
      (tester) async {
    final service = _FakeTrustScoreService();
    dynamic result;
    await tester.pumpWidget(
      _launcher(
        open: (context) => showDialog<bool>(
          context: context,
          builder: (_) => ReviewReplyDialog(
            reviewId: 'review-1',
            service: service,
          ),
        ),
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publier'));
    await tester.pump();
    expect(service.replyCalls, 0);

    await tester.enterText(find.byType(TextField), 'Merci pour votre avis');
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();
    expect(service.replyCalls, 1);
    expect(service.submittedReply, 'Merci pour votre avis');
    expect(result, isTrue);
  });

  testWidgets('trust score card renders loading, empty and info states',
      (tester) async {
    final completer = Completer<TrustScoreProfile>();
    final service = _FakeTrustScoreService()..profileFuture = completer.future;

    await tester.pumpWidget(
      _host(TrustScoreCard(userId: 'user-1', service: service)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_profile());
    await tester.pumpAndSettle();
    expect(find.text('Score Confiance iliprestō'), findsOneWidget);
    expect(find.text('Aucun avis vérifié pour le moment.'), findsOneWidget);

    await tester.tap(find.byTooltip('En savoir plus sur les avis vérifiés'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
  });

  testWidgets('trust score card renders error and published summary states',
      (tester) async {
    final errorCompleter = Completer<TrustScoreProfile>();
    final errorService = _FakeTrustScoreService()
      ..profileFuture = errorCompleter.future;
    await tester.pumpWidget(
      _host(TrustScoreCard(userId: 'user-error', service: errorService)),
    );
    await tester.pump();
    errorCompleter.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger les avis.'), findsOneWidget);

    final successService = _FakeTrustScoreService()
      ..profileFuture = Future<TrustScoreProfile>.value(_profile(published: true));
    await tester.pumpWidget(
      _host(
        TrustScoreCard(
          key: const ValueKey<String>('published'),
          userId: 'user-published',
          service: successService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4,6 / 5'), findsOneWidget);
    expect(find.text('Basé sur 2 avis vérifiés'), findsOneWidget);
    expect(find.text('Communication'), findsOneWidget);
    expect(find.text('Ponctualité'), findsOneWidget);
    expect(find.text('Qualité'), findsOneWidget);
    expect(find.text('Top prestataire'), findsOneWidget);
    expect(find.text('Ponctuel'), findsOneWidget);
  });

  testWidgets('trust score card reloads when the user changes', (tester) async {
    final service = _FakeTrustScoreService();
    await tester.pumpWidget(
      _host(TrustScoreCard(userId: 'user-a', service: service)),
    );
    await tester.pumpAndSettle();
    expect(service.profileCalls, 1);

    await tester.pumpWidget(
      _host(TrustScoreCard(userId: 'user-b', service: service)),
    );
    await tester.pumpAndSettle();
    expect(service.profileCalls, 2);
  });

  testWidgets('review list preview renders verified review details',
      (tester) async {
    final service = _FakeTrustScoreService();
    await tester.pumpWidget(
      _host(
        ReviewListPreview(
          userId: 'other-user',
          reviews: <VerifiedReviewPreview>[
            VerifiedReviewPreview(
              reviewId: 'review-2',
              offerTitle: 'Aide au rangement',
              averageRating: 4.5,
              comment: 'Très fiable',
              replyText: null,
              reviewerRole: 'requester',
              reviewedRole: 'provider',
              roleLabel: 'prestataire',
              createdAt: DateTime(2026, 7, 10),
            ),
          ],
          service: service,
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4,5 / 5'), findsOneWidget);
    expect(find.text('Aide au rangement'), findsOneWidget);
    expect(find.text('Très fiable'), findsOneWidget);
    expect(find.text('10/07/2026'), findsOneWidget);
    expect(find.text('Répondre'), findsNothing);
    expect(find.text('Signaler'), findsNothing);
  });
}
