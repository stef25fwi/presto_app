class AdminContactInboxSummary {
  final int unreadCount;

  const AdminContactInboxSummary({required this.unreadCount});
  const AdminContactInboxSummary.empty() : unreadCount = 0;

  factory AdminContactInboxSummary.fromDynamic(Object? value) {
    final data = adminContactAsStringMap(value);
    final unread = data['unreadCount'];
    return AdminContactInboxSummary(
      unreadCount:
          unread is num ? unread.toInt() : int.tryParse('$unread') ?? 0,
    );
  }
}

class AdminContactMailItem {
  final String id;
  final String senderName;
  final String senderEmail;
  final String subject;
  final String preview;
  final String body;
  final int receivedAt;
  final bool isRead;
  final int attachmentCount;

  const AdminContactMailItem({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.subject,
    required this.preview,
    required this.body,
    required this.receivedAt,
    required this.isRead,
    required this.attachmentCount,
  });

  factory AdminContactMailItem.fromDynamic(Object? value) {
    final data = adminContactAsStringMap(value);
    int asInt(Object? input) =>
        input is num ? input.toInt() : int.tryParse('$input') ?? 0;
    return AdminContactMailItem(
      id: '${data['id'] ?? ''}',
      senderName: '${data['senderName'] ?? ''}'.trim(),
      senderEmail: '${data['senderEmail'] ?? ''}'.trim(),
      subject: '${data['subject'] ?? ''}'.trim(),
      preview: '${data['preview'] ?? ''}'.trim(),
      body: '${data['body'] ?? ''}'.trim(),
      receivedAt: asInt(data['receivedAt']),
      isRead: data['isRead'] == true,
      attachmentCount: asInt(data['attachmentCount']),
    );
  }

  String get senderLabel {
    if (senderName.isNotEmpty && senderEmail.isNotEmpty) {
      return '$senderName <$senderEmail>';
    }
    return senderName.isNotEmpty ? senderName : senderEmail;
  }

  AdminContactMailItem copyWith({bool? isRead}) => AdminContactMailItem(
        id: id,
        senderName: senderName,
        senderEmail: senderEmail,
        subject: subject,
        preview: preview,
        body: body,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
        attachmentCount: attachmentCount,
      );
}

Map<String, dynamic> adminContactAsStringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return const <String, dynamic>{};
}

String formatAdminContactMailDate(int millis) {
  if (millis <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  final now = DateTime.now();
  final sameDay = date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
  String two(int value) => value.toString().padLeft(2, '0');
  if (sameDay) return '${two(date.hour)}:${two(date.minute)}';
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
