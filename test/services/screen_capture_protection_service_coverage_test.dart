import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/screen_capture_protection_service.dart';

void main() {
  tearDown(ScreenCaptureProtection.resetForTest);

  test('does nothing outside Android', () async {
    final methods = <String>[];
    ScreenCaptureProtection.configureForTest(
      isAndroid: () => false,
      methodInvoker: (method) async {
        methods.add(method);
        return null;
      },
    );

    await ScreenCaptureProtection.enable();
    await ScreenCaptureProtection.disable();

    expect(methods, isEmpty);
  });

  test('invokes enable and disable on Android', () async {
    final methods = <String>[];
    ScreenCaptureProtection.configureForTest(
      isAndroid: () => true,
      methodInvoker: (method) async {
        methods.add(method);
        return null;
      },
    );

    await ScreenCaptureProtection.enable();
    await ScreenCaptureProtection.disable();

    expect(methods, <String>['enable', 'disable']);
  });

  test('absorbs method channel failures', () async {
    ScreenCaptureProtection.configureForTest(
      isAndroid: () => true,
      methodInvoker: (_) async => throw StateError('channel unavailable'),
    );

    await ScreenCaptureProtection.enable();
    await ScreenCaptureProtection.disable();
  });
}
