import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';
import 'package:presto_app/features/offers/public_offers_read_diagnostics.dart';
import 'package:presto_app/services/public_offers_query_helpers.dart';

PublicOffersReadIssue _issue({
  required String source,
  required String kind,
  required String message,
  String? code,
  bool authenticated = false,
  String appCheckState = 'failed',
}) {
  return PublicOffersReadIssue(
    source: source,
    kind: kind,
    code: code,
    releaseMessage: message,
    rawMessage: '$source raw failure',
    hasAuthenticatedUser: authenticated,
    appCheckState: appCheckState,
  );
}

void main() {
  setUp(() {
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
    appCheckActivationError = null;
    appCheckActivationStackTrace = null;
  });

  test('fusionne les diagnostics avec l état App Check courant', () {
    appCheckActivationAttempted = true;
    final rules = _issue(
      source: 'listings',
      kind: 'rules',
      code: 'permission-denied',
      message: 'Accès refusé.',
    );
    final appCheck = _issue(
      source: 'offers',
      kind: 'app_check',
      code: 'app-check',
      message: 'Sécurité indisponible.',
      authenticated: true,
    );

    final merged = mergePublicOffersReadIssuesWithAppCheck(
      source: 'merged-public-offers',
      primary: rules,
      secondary: appCheck,
    );

    expect(merged.source, 'merged-public-offers');
    expect(merged.kind, 'app_check');
    expect(merged.code, 'app-check');
    expect(merged.hasAuthenticatedUser, isTrue);
    expect(merged.appCheckState, 'failed');
    expect(merged.rawMessage, contains('listings raw failure'));
    expect(merged.rawMessage, contains('offers raw failure'));
  });

  test('propage un diagnostic structuré dans les wrappers App Check', () {
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = true;
    final issue = _issue(
      source: 'canonical-listings',
      kind: 'network',
      code: 'unavailable',
      message: 'Connexion réseau indisponible.',
      appCheckState: 'ok',
    );
    final error = PublicOffersReadException(issue);

    final diagnosed = diagnosePublicOffersReadIssueWithAppCheck(
      error,
      source: 'wrapper-source',
    );
    final friendly = friendlyPublicOffersReadErrorWithAppCheck(
      error,
      debug: false,
    );

    expect(diagnosed, same(issue));
    expect(friendly, 'Connexion réseau indisponible.');
    expect(publicOffersAppCheckStateLabel(), 'ok');
  });

  testWidgets('construit la carte de debug avec le diagnostic structuré',
      (tester) async {
    final primary = _issue(
      source: 'primary',
      kind: 'index',
      code: 'failed-precondition',
      message: 'Index en cours de création.',
    );
    final secondary = _issue(
      source: 'secondary',
      kind: 'network',
      code: 'unavailable',
      message: 'Réseau indisponible.',
    );
    final error = PublicOffersReadException(
      primary,
      secondaryIssue: secondary,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildPublicOffersDebugCardWithAppCheck(
            error,
            source: 'debug-card',
          ),
        ),
      ),
    );

    expect(find.byType(Container), findsWidgets);
    expect(find.textContaining('[DEBUG OFFERS]'), findsOneWidget);
    expect(find.textContaining('source=primary'), findsOneWidget);
    expect(find.textContaining('source=secondary'), findsOneWidget);
  });

  test('retourne une fusion vide quand aucune requête n est fournie', () async {
    final documents = await loadMergedPublicOfferQueryVariants(
      queries: const [],
      source: 'empty-query-list',
    );

    expect(documents, isEmpty);
  });
}
