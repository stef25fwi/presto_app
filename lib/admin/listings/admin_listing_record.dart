import 'package:cloud_firestore/cloud_firestore.dart';

class AdminListingRecord {
  const AdminListingRecord({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.status,
    required this.city,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String ownerId;
  final String status;
  final String city;
  final DateTime? createdAt;

  factory AdminListingRecord.fromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return AdminListingRecord(
      id: id.trim(),
      title: _firstNonEmpty(<Object?>[
        data['title'],
        data['name'],
      ], fallback: 'Annonce sans titre'),
      ownerId: _firstNonEmpty(<Object?>[
        data['ownerId'],
        data['userId'],
        data['authorId'],
      ]),
      status: _firstNonEmpty(<Object?>[
        data['status'],
      ], fallback: 'unknown').toLowerCase(),
      city: _firstNonEmpty(<Object?>[
        data['city'],
        data['location'],
        data['ville'],
      ]),
      createdAt: _readDate(data['createdAt'] ?? data['publishedAt']),
    );
  }

  bool get isActiveForStatistics => status != 'deleted' && status != 'archived';
}

String _firstNonEmpty(
  Iterable<Object?> values, {
  String fallback = '',
}) {
  for (final value in values) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}
