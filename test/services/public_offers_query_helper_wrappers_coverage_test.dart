import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';
import 'package:presto_app/features/offers/public_offers_read_diagnostics.dart';
import 'package:presto_app/services/public_offers_query_helpers.dart';

const _primaryIssue = PublicOffersReadIssue(
  source: 'primary',
  kind: 'network',
  releaseMessage: 'Connexion réseau indisponible.',
  rawMessage: 'SocketException: offline',
  hasAuthenticatedUser: false,
  appCheckState: 'unknown',
  code: 'network',
);

const _secondaryIssue = PublicOffersReadIssue(
  source: 'secondary',
  kind: 'rules',
  releaseMessage: 'Accès refusé.',
  rawMessage: 'permission-denied',
  hasAuthenticatedUser: true,
  appCheckState: 'unknown',
  code: 'permission-denied',
);

void main() {
  setUp(() {
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
    appCheckActivationError = null;
    appCheckActivationStackTrace = null;
  });

  test('merges diagnostics while propagating the App Check state', () {
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = false;

    final merged = mergePublicOffersReadIssuesWithAppCheck(
      source: 'merged-source',
      primary: _primaryIssue,
      secondary: _secondaryIssue,
    );

    expect(merged.source, 'merged-source');
    expect(merged.kind, 'rules');
    expect(merged.code, 'permission-denied');
    expect(merged.hasAuthenticatedUser, isTrue);
    expect(merged.appCheckState, 'failed');
    expect(merged.rawMessage, contains('primary'));
    expect(merged.rawMessage, contains('secondary'));
  });

  test('reuses a structured exception in diagnostic and friendly wrappers', () {
    final error = PublicOffersReadException(
      _primaryIssue,
      secondaryIssue: _secondaryIssue,
    );

    final diagnosed = diagnosePublicOffersReadIssueWithAppCheck(
      error,
      source: 'wrapper-source',
    );
    final friendly = friendlyPublicOffersReadErrorWithAppCheck(
      error,
      debug: false,
    );
    final debugCard = buildPublicOffersDebugCardWithAppCheck(
      error,
      source: 'wrapper-source',
    );

    expect(identical(diagnosed, _primaryIssue), isTrue);
    expect(friendly, _primaryIssue.releaseMessage);
    expect(debugCard, isNotNull);
  });

  test('returns an empty result when no query variant is supplied', () async {
    final result = await loadMergedPublicOfferQueryVariants(
      queries: const <Query<Map<String, dynamic>>>[],
      source: 'empty-variants',
    );

    expect(result, isEmpty);
  });
}
