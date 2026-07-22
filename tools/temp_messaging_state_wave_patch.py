import re
from pathlib import Path

path = Path('lib/pages/messages/conversation_thread_page.dart')
source = path.read_text()

renames = {
    '_messageStreamErrorMessage': 'messageStreamErrorMessage',
    '_buildThreadDateChip': 'buildThreadDateChip',
    '_conversationInitial': 'conversationInitial',
    '_headerOfferTitle': 'headerOfferTitle',
    '_headerDisplayName': 'headerDisplayName',
    '_headerSubtitle': 'headerSubtitle',
    '_isRecentlySeen': 'isRecentlySeen',
    '_readReceiptLabel': 'readReceiptLabel',
    '_buildStateBanner': 'buildStateBanner',
    '_applyInitialDraftIfNeeded': 'applyInitialDraftIfNeeded',
    '_buildSafetyReminderBanner': 'buildSafetyReminderBanner',
    '_buildTypingIndicator': 'buildTypingIndicator',
    '_controller': 'messageController',
    '_participants': 'threadParticipants',
    '_lastReadAt': 'threadLastReadAt',
    '_didApplyInitialDraft': 'didApplyInitialDraft',
    '_showSafetyReminder': 'showSafetyReminder',
    '_isOtherTyping': 'otherIsTyping',
    '_isAdminViewer': 'adminViewerState',
    '_isBlockedForCurrentUser': 'blockedForCurrentUser',
    '_isBlockedByAnotherParticipant': 'blockedByAnotherParticipant',
    '_isBlocked': 'conversationBlocked',
    '_isArchivedForCurrentUser': 'archivedForCurrentUser',
    '_conversationOfferTitle': 'conversationOfferTitle',
    '_otherParticipantName': 'otherParticipantNameState',
    '_otherPresenceStatus': 'otherPresenceStatus',
    '_otherLastSeenAt': 'otherLastSeenAt',
}

for old, new in renames.items():
    pattern = rf'(?<![A-Za-z0-9_]){re.escape(old)}(?![A-Za-z0-9_])'
    updated, count = re.subn(pattern, new, source)
    if count == 0:
        raise SystemExit(f'missing messaging state helper: {old}')
    source = updated

path.write_text(source)
