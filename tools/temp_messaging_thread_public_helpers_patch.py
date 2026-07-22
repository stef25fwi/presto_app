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

path.write_text(source)
