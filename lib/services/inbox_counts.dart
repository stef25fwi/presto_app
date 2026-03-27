enum InboxCountType {
  totalUnread,
  unreadMessages,
  unreadNotifications,
}

int readInboxCount(
  Map<String, dynamic>? inboxCounts, {
  InboxCountType type = InboxCountType.totalUnread,
}) {
  final data = inboxCounts ?? const <String, dynamic>{};

  switch (type) {
    case InboxCountType.totalUnread:
      return _readCount(data['totalUnread']);
    case InboxCountType.unreadMessages:
      return _readCount(data['unreadMessages']);
    case InboxCountType.unreadNotifications:
      return _readCount(data['unreadNotifications']);
  }
}

int _readCount(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}