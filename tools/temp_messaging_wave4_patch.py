import re
from pathlib import Path

path = Path('lib/pages/messages/conversation_thread_page.dart')
source = path.read_text()

renames = {
    '_ConversationAttachmentGateDecision': 'ConversationAttachmentGateDecision',
    '_showAttachmentSubscriptionGate': 'showAttachmentSubscriptionGate',
    '_showAttachmentActionsSheet': 'showAttachmentActionsSheet',
    '_openAttachment': 'openAttachment',
    '_buildEmojiStrip': 'buildEmojiStrip',
    '_showEmojiStrip': 'showEmojiStripState',
    '_quickEmojis': 'quickEmojisState',
}

for old, new in renames.items():
    pattern = rf'(?<![A-Za-z0-9_]){re.escape(old)}(?![A-Za-z0-9_])'
    updated, count = re.subn(pattern, new, source)
    if count == 0:
        raise SystemExit(f'missing messaging wave 4 identifier: {old}')
    source = updated

compact_guard = (
    '    if (!showEmojiStripState || conversationBlocked) '
    'return const SizedBox.shrink();'
)
expanded_guard = """    if (!showEmojiStripState || conversationBlocked) {
      return const SizedBox.shrink();
    }"""
if compact_guard not in source:
    raise SystemExit('messaging emoji strip compact guard not found')
source = source.replace(compact_guard, expanded_guard, 1)

path.write_text(source)
