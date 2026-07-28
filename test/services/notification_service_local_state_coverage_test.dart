import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:notifications-test',
          messagingSenderId: '1234567890',
          projectId: 'presto-notifications-test',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('factory returns the same notification service instance', () {
    expect(identical(NotificationService(), NotificationService()), isTrue);
  });

  test('ignores an empty user when persisting prompt dismissal', () async {
    final service = NotificationService();

    await service.markMessagingPermissionPromptDismissed('   ');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isEmpty);
  });

  test('persists a normalized messaging prompt dismissal timestamp', () async {
    final service = NotificationService();

    await service.markMessagingPermissionPromptDismissed(' user-42 ');

    final preferences = await SharedPreferences.getInstance();
    final timestamp = preferences.getInt(
      'notifications.messaging_prompt.dismissed_at.user-42',
    );
    expect(timestamp, isNotNull);
    expect(timestamp!, greaterThan(0));
  });

  test('clears an existing prompt dismissal and ignores an empty user', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'notifications.messaging_prompt.dismissed_at.user-42': 123,
    });
    final service = NotificationService();

    await service.clearMessagingPermissionPromptDismissed(' user-42 ');
    await service.clearMessagingPermissionPromptDismissed('   ');

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.containsKey(
        'notifications.messaging_prompt.dismissed_at.user-42',
      ),
      isFalse,
    );
  });

  test('cold-start route consumption is destructive even when empty', () {
    final service = NotificationService();

    expect(service.consumeColdStartRoute(), isNull);
    expect(service.consumeColdStartRoute(), isNull);
  });

  test('native activation failure message remains actionable', () {
    final message = NotificationService().pushActivationFailureMessage();

    expect(message, contains('permission a été accordée'));
    expect(message, contains('configuration FCM'));
  });

  testWidgets('navigator readiness can be marked without a pending route',
      (tester) async {
    final service = NotificationService();

    service.markNavigatorReady();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
