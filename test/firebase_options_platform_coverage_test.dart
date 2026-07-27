import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/firebase_options.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('sélectionne les options Firebase de chaque plateforme native', () {
    final cases = <TargetPlatform, Object>{
      TargetPlatform.android: DefaultFirebaseOptions.android,
      TargetPlatform.iOS: DefaultFirebaseOptions.ios,
      TargetPlatform.macOS: DefaultFirebaseOptions.macos,
      TargetPlatform.windows: DefaultFirebaseOptions.windows,
      TargetPlatform.linux: DefaultFirebaseOptions.linux,
      TargetPlatform.fuchsia: DefaultFirebaseOptions.web,
    };

    for (final entry in cases.entries) {
      debugDefaultTargetPlatformOverride = entry.key;
      expect(identical(DefaultFirebaseOptions.currentPlatform, entry.value), isTrue);
    }
  });
}
