import re
from pathlib import Path

path = Path('lib/pages/messages/conversation_thread_page.dart')
source = path.read_text()

renames = {
    '_ConversationThreadAction': 'ConversationThreadAction',
    '_handleConversationAction': 'handleConversationAction',
    '_ConversationAttachmentGateDecision': 'ConversationAttachmentGateDecision',
    '_showAttachmentSubscriptionGate': 'showAttachmentSubscriptionGate',
    '_showAttachmentActionsSheet': 'showAttachmentActionsSheet',
    '_openAttachmentWithChooser': 'openAttachmentWithChooser',
    '_openAttachment': 'openAttachment',
    '_recordEmojiUsage': 'recordEmojiUsage',
    '_buildEmojiStrip': 'buildEmojiStrip',
    '_showEmojiStrip': 'showEmojiStripState',
    '_quickEmojis': 'quickEmojisState',
    '_emojiUsageCounts': 'emojiUsageCountsState',
}

for old, new in renames.items():
    pattern = rf'(?<![A-Za-z0-9_]){re.escape(old)}(?![A-Za-z0-9_])'
    updated, count = re.subn(pattern, new, source)
    if count == 0:
        raise SystemExit(f'missing messaging wave 4 identifier: {old}')
    source = updated

path.write_text(source)
