from pathlib import Path

path = Path('lib/pages/messages/conversation_thread_page.dart')
source = path.read_text()

renames = {
    '_conversationValue': 'conversationValue',
    '_messagingErrorCode': 'messagingErrorCode',
    '_sendMessageErrorMessage': 'sendMessageErrorMessage',
    '_attachmentUploadErrorMessage': 'attachmentUploadErrorMessage',
    '_isSameCalendarDay': 'isSameCalendarDay',
    '_readText': 'readText',
    '_readStringMap': 'readStringMap',
    '_firstProfilePhotoValue': 'firstProfilePhotoValue',
    '_firstStoredProfilePhotoPath': 'firstStoredProfilePhotoPath',
    '_isResolvableStorageProfilePhoto': 'isResolvableStorageProfilePhoto',
    '_isNetworkProfilePhoto': 'isNetworkProfilePhoto',
    '_safeAttachmentName': 'safeAttachmentName',
    '_mimeTypeForName': 'mimeTypeForName',
    '_attachmentTypeForFile': 'attachmentTypeForFile',
    '_attachmentMessageText': 'attachmentMessageText',
    '_shouldHideAttachmentText': 'shouldHideAttachmentText',
    '_OptimisticMessageStatus': 'OptimisticMessageStatus',
    '_OptimisticMessage': 'OptimisticMessage',
    '_MessageModeration': 'MessageModeration',
    '_MessageAttachment': 'MessageAttachment',
    '_OfferPreview': 'OfferPreview',
    '_formatMessageTimestamp': 'formatMessageTimestamp',
    '_formatThreadDateLabel': 'formatThreadDateLabel',
    '_formatPresenceSeenAt': 'formatPresenceSeenAt',
    '_isDeletedUserMap': 'isDeletedUserMap',
    '_deletedAwareDisplayName': 'deletedAwareDisplayName',
    '_deletedAwareAvatar': 'deletedAwareAvatar',
}

for old, new in renames.items():
    if old not in source:
        raise SystemExit(f'missing messaging helper: {old}')
    source = source.replace(old, new)

# The legacy page is already at its architecture line ceiling. Remove only
# optional blank separators inside its state class so dart format can apply the
# testability rename without increasing the production file size.
lines = source.splitlines()
compacted = []
inside_state = False
removed_blank_lines = 0
for line in lines:
    if line.startswith('class _ConversationThreadPageState'):
        inside_state = True
    if line.startswith('enum OptimisticMessageStatus'):
        inside_state = False
    if inside_state and removed_blank_lines < 120 and not line.strip():
        removed_blank_lines += 1
        continue
    compacted.append(line)

if removed_blank_lines < 40:
    raise SystemExit(
        f'not enough optional blank lines to preserve architecture budget: {removed_blank_lines}'
    )

path.write_text('\n'.join(compacted) + '\n')
