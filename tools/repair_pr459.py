#!/usr/bin/env python3
"""Temporary deterministic repair for PR #459.

This script patches the two invalid CircleAvatar callbacks and removes the
corresponding test exception drain. It is intentionally idempotent.
"""

from pathlib import Path


SOURCE_PATH = Path("lib/pages/messages/conversation_thread_page.dart")
TEST_PATH = Path("test/pages/messages/conversation_thread_page_shell_test.dart")

HEADER_OLD = """            onForegroundImageError: (error, stackTrace) {
              debugPrint(
                '[ConversationThread] header avatar load failed '
                'participantId=$_otherParticipantId url=$_otherParticipantPhotoUrl '
                'error=$error',
              );
            },
"""
HEADER_NEW = """            onForegroundImageError: _otherParticipantPhotoUrl.isNotEmpty
                ? (error, stackTrace) {
                    debugPrint(
                      '[ConversationThread] header avatar load failed '
                      'participantId=$_otherParticipantId url=$_otherParticipantPhotoUrl '
                      'error=$error',
                    );
                  }
                : null,
"""

BUBBLE_OLD = """      onForegroundImageError: (error, stackTrace) {
        debugPrint(
          '[ConversationThread] bubble avatar load failed '
          'participantId=$_otherParticipantId url=$_otherParticipantPhotoUrl '
          'error=$error',
        );
      },
"""
BUBBLE_NEW = """      onForegroundImageError: _otherParticipantPhotoUrl.isNotEmpty
          ? (error, stackTrace) {
              debugPrint(
                '[ConversationThread] bubble avatar load failed '
                'participantId=$_otherParticipantId url=$_otherParticipantPhotoUrl '
                'error=$error',
              );
            }
          : null,
"""

DRAIN_HELPER = """void _drainExpectedConversationThreadExceptions(WidgetTester tester) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    final message = exception.toString();
    final isExpectedCircleAvatarAssertion =
        message.contains('circle_avatar.dart') &&
        message.contains(
          'foregroundImage != null || onForegroundImageError == null',
        );
    if (!isExpectedCircleAvatarAssertion) {
      throw exception!;
    }
  }
}

"""


def replace_once_or_confirm(text: str, before: str, after: str, label: str) -> str:
    if after in text:
        return text
    count = text.count(before)
    if count != 1:
        raise RuntimeError(f"{label}: expected one occurrence, found {count}")
    return text.replace(before, after, 1)


def main() -> None:
    source = SOURCE_PATH.read_text(encoding="utf-8")
    source = replace_once_or_confirm(
        source,
        HEADER_OLD,
        HEADER_NEW,
        "header avatar callback",
    )
    source = replace_once_or_confirm(
        source,
        BUBBLE_OLD,
        BUBBLE_NEW,
        "bubble avatar callback",
    )
    SOURCE_PATH.write_text(source, encoding="utf-8")

    test = TEST_PATH.read_text(encoding="utf-8")
    test = test.replace(DRAIN_HELPER, "")
    test = test.replace(
        "  _drainExpectedConversationThreadExceptions(tester);\n",
        "",
    )
    TEST_PATH.write_text(test, encoding="utf-8")

    print("PR459 source and test repair: OK")


if __name__ == "__main__":
    main()
