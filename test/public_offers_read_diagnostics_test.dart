import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/public_offers_read_diagnostics.dart';

PublicOffersReadIssue _issue({
  String source = 'primary',
  String kind = 'unknown',
  String releaseMessage = 'Message public',
  String rawMessage = 'raw failure',
  bool hasAuthenticatedUser = false,
  String appCheckState = 'ok',
  String? code,
}) {
  return PublicOffersReadIssue(
    source: source,
    kind: kind,
    releaseMessage: releaseMessage,
    rawMessage: rawMessage,
    hasAuthenticatedUser: hasAuthenticatedUser,
    appCheckState: appCheckState,
    code: code,
  );
}

void main() {
  test('formats release and debug messages with normalized raw details', () {
    final issue = _issue(
      kind: 'rules',
      code: 'permission-denied',
      rawMessage: '  Firestore\n permission   denied  ',
      hasAuthenticatedUser: true,
    );

    expect(issue.message(debug: false), 'Message public');
    expect(issue.message(debug: true), contains('[DEBUG OFFERS]'));
    expect(issue.debugLine, contains('source=primary'));
    expect(issue.debugLine, contains('kind=rules'));
    expect(issue.debugLine, contains('code=permission-denied'));
    expect(issue.debugLine, contains('auth=signed-in'));
    expect(issue.debugLine, contains('appCheck=ok'));
    expect(issue.debugLine, contains('raw=Firestore permission denied'));

    final noOptionalDetails = _issue(code: ' ', rawMessage: ' ');
    expect(noOptionalDetails.debugLine, isNot(contains('code=')));
    expect(noOptionalDetails.debugLine, isNot(contains('raw=')));
    expect(noOptionalDetails.debugLine, contains('auth=public'));
  });

  test('normalizes and truncates debug text', () {
    expect(truncatePublicOffersDebugText('  a\n b\t c  '), 'a b c');
    expect(
      truncatePublicOffersDebugText('abcdefghijk', maxLength: 8),
      'abcde...',
    );
    expect(
      truncatePublicOffersDebugText('short', maxLength: 8),
      'short',
    );
  });

  test('extracts stable error codes from typed and textual errors', () {
    final wrapped = PublicOffersReadException(
      _issue(code: 'wrapped-code'),
    );
    expect(publicOffersErrorCode(wrapped), 'wrapped-code');
    expect(
      publicOffersErrorCode(
        FirebaseException(plugin: 'cloud_firestore', code: ' unavailable '),
      ),
      'unavailable',
    );

    final cases = <String, String>{
      'Firestore index missing': 'failed-precondition',
      'permission-denied by rules': 'permission-denied',
      'request unauthenticated': 'unauthenticated',
      'deadline-exceeded': 'deadline-exceeded',
      'backend unavailable': 'unavailable',
      'network disconnected': 'network',
    };
    for (final entry in cases.entries) {
      expect(publicOffersErrorCode(Exception(entry.key)), entry.value);
    }
    expect(publicOffersErrorCode(Exception('other failure')), isNull);
  });

  test('exception combines primary and secondary diagnostics', () {
    final primary = _issue(kind: 'rules', code: 'permission-denied');
    final secondary = _issue(
      source: 'fallback',
      kind: 'network',
      code: 'unavailable',
    );
    final single = PublicOffersReadException(primary);
    final combined = PublicOffersReadException(
      primary,
      secondaryIssue: secondary,
    );

    expect(single.message(debug: false), primary.releaseMessage);
    expect(single.message(debug: true), primary.message(debug: true));
    expect(combined.message(debug: true), contains(primary.debugLine));
    expect(combined.message(debug: true), contains(secondary.debugLine));
    expect(combined.toString(), combined.message(debug: true));
  });

  test('merges issues using diagnostic priority and combined context', () {
    final merged = mergePublicOffersReadIssues(
      source: 'merged',
      primary: _issue(
        source: 'cache',
        kind: 'unknown',
        rawMessage: 'cache failed',
      ),
      secondary: _issue(
        source: 'firestore',
        kind: 'app_check',
        code: 'app-check',
        rawMessage: 'token rejected',
        hasAuthenticatedUser: true,
      ),
      appCheckState: 'failed',
    );

    expect(merged.source, 'merged');
    expect(merged.kind, 'app_check');
    expect(merged.code, 'app-check');
    expect(merged.hasAuthenticatedUser, isTrue);
    expect(merged.appCheckState, 'failed');
    expect(merged.rawMessage, contains('cache: cache failed'));
    expect(merged.rawMessage, contains('firestore: token rejected'));

    final primaryWins = mergePublicOffersReadIssues(
      source: 'merged',
      primary: _issue(kind: 'rules'),
      secondary: _issue(kind: 'network'),
      appCheckState: 'ok',
    );
    expect(primaryWins.kind, 'rules');
  });

  test('diagnoses index and explicit App Check failures', () {
    final index = diagnosePublicOffersReadIssue(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'Index required',
      ),
      source: 'firestore',
      appCheckState: 'ok',
      hasAuthenticatedUser: false,
    );
    expect(index.kind, 'index');
    expect(index.code, 'failed-precondition');
    expect(index.releaseMessage, contains('mise à jour'));

    final appCheck = diagnosePublicOffersReadIssue(
      Exception('AppCheck token attestation rejected by reCAPTCHA'),
      source: 'firestore',
      appCheckState: 'failed',
      hasAuthenticatedUser: true,
    );
    expect(appCheck.kind, 'app_check');
    expect(appCheck.code, 'app-check');
    expect(appCheck.hasAuthenticatedUser, isTrue);
  });

  test('attributes permission failures according to App Check health', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Denied',
    );

    for (final state in const ['failed', 'not-attempted', 'unknown']) {
      final issue = diagnosePublicOffersReadIssue(
        error,
        source: 'firestore',
        appCheckState: state,
        hasAuthenticatedUser: false,
      );
      expect(issue.kind, 'app_check');
      expect(issue.releaseMessage, contains('App Check'));
    }

    final rules = diagnosePublicOffersReadIssue(
      error,
      source: 'firestore',
      appCheckState: 'ok',
      hasAuthenticatedUser: false,
    );
    expect(rules.kind, 'rules');
    expect(rules.releaseMessage, contains('règles Firestore'));
  });

  test('diagnoses auth, network and unknown failures', () {
    final auth = diagnosePublicOffersReadIssue(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
      ),
      source: 'firestore',
      appCheckState: 'ok',
      hasAuthenticatedUser: false,
    );
    expect(auth.kind, 'auth');

    final networkErrors = <Object>[
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded'),
      Exception('SocketException: network is down'),
      Exception('XMLHttpRequest failed'),
      Exception('ClientException while loading'),
    ];
    for (final error in networkErrors) {
      final issue = diagnosePublicOffersReadIssue(
        error,
        source: 'firestore',
        appCheckState: 'ok',
        hasAuthenticatedUser: false,
      );
      expect(issue.kind, 'network');
      expect(issue.releaseMessage, 'Connexion réseau indisponible.');
    }

    final unknown = diagnosePublicOffersReadIssue(
      Exception('unexpected response'),
      source: 'cache',
      appCheckState: 'ok',
      hasAuthenticatedUser: true,
    );
    expect(unknown.kind, 'unknown');
    expect(unknown.code, isNull);
    expect(unknown.hasAuthenticatedUser, isTrue);
  });

  test('keeps existing issues and builds friendly messages', () {
    final issue = _issue(kind: 'network', code: 'unavailable');
    final exception = PublicOffersReadException(issue);

    expect(
      diagnosePublicOffersReadIssue(
        exception,
        source: 'ignored',
        appCheckState: 'ignored',
      ),
      same(issue),
    );
    expect(
      publicOffersReadIssueFromError(
        exception,
        source: 'ignored',
        appCheckState: 'ignored',
      ),
      same(issue),
    );
    expect(
      friendlyPublicOffersReadError(
        exception,
        appCheckState: 'ok',
        debug: false,
      ),
      issue.releaseMessage,
    );
    expect(
      friendlyPublicOffersReadError(
        exception,
        appCheckState: 'ok',
        debug: true,
      ),
      contains('[DEBUG OFFERS]'),
    );

    final diagnosed = publicOffersReadIssueFromError(
      Exception('network failure'),
      source: 'cache',
      appCheckState: 'ok',
      hasAuthenticatedUser: false,
    );
    expect(diagnosed.kind, 'network');
  });

  testWidgets('builds the debug card including secondary diagnostics',
      (tester) async {
    final exception = PublicOffersReadException(
      _issue(kind: 'rules', code: 'permission-denied'),
      secondaryIssue: _issue(
        source: 'fallback',
        kind: 'network',
        code: 'unavailable',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildPublicOffersDebugCard(
            exception,
            source: 'firestore',
            appCheckState: 'ok',
            hasAuthenticatedUser: false,
          ),
        ),
      ),
    );

    expect(find.textContaining('[DEBUG OFFERS]'), findsOneWidget);
    final text = tester.widget<Text>(find.textContaining('[DEBUG OFFERS]'));
    expect(text.data, contains('source=primary'));
    expect(text.data, contains('source=fallback'));
    expect(text.style?.fontSize, 11);
    expect(text.style?.fontWeight, FontWeight.w600);
  });

  test('logging a diagnosed error is best effort and does not throw', () async {
    logPublicOffersReadError(
      'firestore',
      Exception('permission-denied'),
      appCheckState: 'ok',
      stackTrace: StackTrace.fromString('first\nsecond\nthird'),
      hasAuthenticatedUser: false,
    );
    await Future<void>.delayed(Duration.zero);
  });
}
