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

path.write_text(source)
