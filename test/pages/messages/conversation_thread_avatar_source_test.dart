import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les erreurs image restent conditionnées à une vraie image', () {
    final source = File(
      'lib/pages/messages/conversation_thread_page.dart',
    ).readAsStringSync();

    const guardedCallback =
        'onForegroundImageError: _otherParticipantPhotoUrl.isNotEmpty';

    expect(guardedCallback.allMatches(source), hasLength(2));
    expect(
      RegExp(r'onForegroundImageError:\s*\(error, stackTrace\)').hasMatch(source),
      isFalse,
    );
  });

  test('le test du shell ne masque plus les assertions Flutter', () {
    final testSource = File(
      'test/pages/messages/conversation_thread_page_shell_test.dart',
    ).readAsStringSync();

    expect(
      testSource,
      isNot(contains('_drainExpectedConversationThreadExceptions')),
    );
    expect(
      testSource,
      isNot(contains('foregroundImage != null || onForegroundImageError == null')),
    );
  });
}
