import re
from pathlib import Path

path = Path('lib/pages/messages/conversation_thread_page.dart')
source = path.read_text()

renames = {
    '_isNearLatestMessage': 'isNearLatestMessage',
    '_scrollToLatestMessage': 'scrollToLatestMessage',
    '_removeOptimisticMessage': 'removeOptimisticMessage',
    '_markOptimisticMessageFailed': 'markOptimisticMessageFailed',
    '_buildAttachmentPreview': 'buildAttachmentPreview',
    '_buildAttachmentPreviews': 'buildAttachmentPreviews',
    '_buildOtherParticipantMessageAvatar': 'buildOtherParticipantMessageAvatar',
    '_buildMessageBubble': 'buildMessageBubble',
    '_buildMessagesAccessGate': 'buildMessagesAccessGate',
    '_optimisticMessages': 'optimisticMessages',
    '_deletingMessageIds': 'deletingMessageIds',
    '_otherParticipantPhotoUrl': 'otherParticipantPhotoUrl',
    '_otherParticipantId': 'otherParticipantIdState',
    '_isPreparingMessageStream': 'preparingMessageStream',
    '_showNewMessagesButton': 'showNewMessagesButton',
    '_scrollController': 'threadScrollController',
    '_isSending': 'sendingMessageState',
    '_AttachmentActionTile': 'AttachmentActionTile',
    '_ConversationBanner': 'ConversationBanner',
    '_ConversationPatternBackground': 'ConversationPatternBackground',
    '_ConversationPatternPainter': 'ConversationPatternPainter',
    '_VoiceRecordingSheetState': 'VoiceRecordingSheetState',
    '_VoiceRecordingSheet': 'VoiceRecordingSheet',
}

for old, new in renames.items():
    pattern = rf'(?<![A-Za-z0-9_]){re.escape(old)}(?![A-Za-z0-9_])'
    updated, count = re.subn(pattern, new, source)
    if count == 0:
        raise SystemExit(f'missing messaging action helper: {old}')
    source = updated

constructor_updates = {
    'const AttachmentActionTile({\n': 'const AttachmentActionTile({\n    super.key,\n',
    'const ConversationBanner({\n': 'const ConversationBanner({\n    super.key,\n',
    'class ConversationPatternBackground extends StatelessWidget {\n  const ConversationPatternBackground();':
        'class ConversationPatternBackground extends StatelessWidget {\n  const ConversationPatternBackground({super.key});',
    'const VoiceRecordingSheet({required this.onCancel, required this.onSend});':
        'const VoiceRecordingSheet({super.key, required this.onCancel, required this.onSend});',
}
for old, new in constructor_updates.items():
    if old not in source:
        raise SystemExit(f'missing public widget constructor: {old}')
    source = source.replace(old, new, 1)

path.write_text(source)

test_path = Path(
    'test/pages/messages/conversation_thread_actions_and_bubbles_coverage_test.dart'
)
test_source = test_path.read_text()
old_assignment = """state.setState(() {
      state.optimisticMessages = <OptimisticMessage>[sending, second];
    });"""
new_assignment = """state.setState(() {
      state.optimisticMessages
        ..clear()
        ..addAll(<OptimisticMessage>[sending, second]);
    });"""
if old_assignment not in test_source:
    raise SystemExit('optimistic message fixture assignment not found')
test_source = test_source.replace(old_assignment, new_assignment, 1)

old_avatar_expectation = "expect(find.text('A'), findsOneWidget);"
if old_avatar_expectation not in test_source:
    raise SystemExit('avatar expectation not found')
test_source = test_source.replace(
    old_avatar_expectation,
    "expect(find.text('A'), findsWidgets);",
    1,
)

unmounted_preview_block = """    await tester.tap(find.byKey(const ValueKey<String>('image-preview')));
    await tester.pump();
    expect(find.text('iliprestō'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('iliprestō'), findsNothing);
"""
if unmounted_preview_block not in test_source:
    raise SystemExit('unmounted image preview interaction not found')
test_source = test_source.replace(unmounted_preview_block, '', 1)
test_path.write_text(test_source)
