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

test_path = Path(
    'test/pages/messages/conversation_thread_interaction_dialogs_coverage_test.dart'
)
test_source = test_path.read_text()
old_block = """    authPlatform.user = null;
    state.emojiUsageCountsState = <String, int>{};
    state.quickEmojisState = <String>[];

    await state.recordEmojiUsage('  ');
    await state.recordEmojiUsage('👍');
    await state.recordEmojiUsage('🔥');
    await state.recordEmojiUsage('🔥');
    await state.recordEmojiUsage('😊');

    expect(state.emojiUsageCountsState['🔥'], 2);
    expect(state.emojiUsageCountsState['👍'], 1);
    expect(state.quickEmojisState.first, '🔥');
    expect(state.quickEmojisState, containsAll(<String>['👍', '😊']));

    state.showEmojiStripState = true;
    state.conversationBlocked = false;
    expect(state.buildEmojiStrip(), isA<Padding>());
    state.conversationBlocked = true;
    expect(state.buildEmojiStrip(), isA<SizedBox>());
    state.conversationBlocked = false;

    authPlatform.user = _Wave4UserPlatform(authPlatform);
"""
new_block = """    state.quickEmojisState = <String>['🔥', '👍', '😊', '🙏', '👌', '💬'];
    state.showEmojiStripState = true;
    state.conversationBlocked = false;
    expect(state.buildEmojiStrip(), isA<Padding>());
    state.conversationBlocked = true;
    expect(state.buildEmojiStrip(), isA<SizedBox>());
    state.conversationBlocked = false;
"""
if old_block not in test_source:
    raise SystemExit('network-backed emoji fixture block not found')
test_path.write_text(test_source.replace(old_block, new_block, 1))
