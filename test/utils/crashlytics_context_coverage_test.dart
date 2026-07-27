import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/utils/crashlytics_context.dart';

void main() {
  tearDown(CrashlyticsContext.resetForTest);

  test('writes user ids, keys, logs and recorded errors', () async {
    final userIds = <String>[];
    final keys = <String, Object>{};
    final logs = <String>[];
    Object? recordedError;
    StackTrace? recordedStack;
    String? recordedReason;
    bool? recordedFatal;

    CrashlyticsContext.configureForTest(
      userIdWriter: (uid) async => userIds.add(uid),
      keyWriter: (key, value) async => keys[key] = value,
      logger: (message) async => logs.add(message),
      errorRecorder: (
        error,
        stack, {
        reason,
        fatal = false,
      }) async {
        recordedError = error;
        recordedStack = stack;
        recordedReason = reason;
        recordedFatal = fatal;
      },
    );

    await CrashlyticsContext.setUserId('user-1');
    await CrashlyticsContext.setUserId(null);
    await CrashlyticsContext.setKey('plan', 'ilipro');
    await CrashlyticsContext.setKeys(<String, Object?>{
      'attempt': 2,
      'optional': null,
    });
    await CrashlyticsContext.log('publication started');

    final stack = StackTrace.current;
    final error = StateError('publication failed');
    await CrashlyticsContext.recordError(
      error,
      stack,
      reason: 'publish_offer',
      fatal: true,
      keys: <String, Object?>{'stage': 'upload'},
    );

    expect(userIds, <String>['user-1', '']);
    expect(keys, <String, Object>{
      'plan': 'ilipro',
      'attempt': 2,
      'optional': '',
      'stage': 'upload',
    });
    expect(logs, <String>['publication started']);
    expect(recordedError, same(error));
    expect(recordedStack, same(stack));
    expect(recordedReason, 'publish_offer');
    expect(recordedFatal, isTrue);
  });

  test('absorbs failures from every best-effort boundary', () async {
    CrashlyticsContext.configureForTest(
      userIdWriter: (_) async => throw StateError('user id failed'),
      keyWriter: (_, __) async => throw StateError('key failed'),
      logger: (_) async => throw StateError('log failed'),
      errorRecorder: (
        _,
        __, {
        reason,
        fatal = false,
      }) async =>
          throw StateError('record failed'),
    );

    await CrashlyticsContext.setUserId('user-2');
    await CrashlyticsContext.setKey('key', 'value');
    await CrashlyticsContext.setKeys(<String, Object?>{'one': 1});
    await CrashlyticsContext.log('message');
    await CrashlyticsContext.recordError(
      StateError('source'),
      StackTrace.current,
    );
  });
}
