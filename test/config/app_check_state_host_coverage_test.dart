import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';

void main() {
  group('App Check web host classification', () {
    test('detects every supported local host', () {
      expect(isLocalAppCheckWebHost('localhost'), isTrue);
      expect(isLocalAppCheckWebHost('127.0.0.1'), isTrue);
      expect(isLocalAppCheckWebHost('0.0.0.0'), isTrue);
      expect(isLocalAppCheckWebHost('example.test'), isFalse);
    });

    test('detects GitHub and named preview hosts', () {
      expect(isPreviewAppCheckWebHost('workspace.app.github.dev'), isTrue);
      expect(isPreviewAppCheckWebHost('workspace.github.dev'), isTrue);
      expect(isPreviewAppCheckWebHost('ilipresto-preview.example'), isTrue);
      expect(isPreviewAppCheckWebHost('ilipresto.fr'), isFalse);
    });

    test('classifies normalized hosts across every category', () {
      expect(appCheckWebHostClass('   '), 'unknown');
      expect(appCheckWebHostClass(' ILIPRESTO.FR '), 'prod');
      expect(appCheckWebHostClass(' LOCALHOST '), 'local');
      expect(appCheckWebHostClass('feature.app.github.dev'), 'preview');
      expect(appCheckWebHostClass('custom.example'), 'custom');
    });
  });
}
