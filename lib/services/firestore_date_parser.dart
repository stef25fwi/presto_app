import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? parseFirestoreDateTime(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    if (value <= 0) return null;
    final normalized = value < 1000000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(normalized);
  }
  if (value is double) {
    if (!value.isFinite || value <= 0) return null;
    final integerValue = value.floor();
    final normalized =
        integerValue < 1000000000000 ? integerValue * 1000 : integerValue;
    return DateTime.fromMillisecondsSinceEpoch(normalized);
  }
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final asInt = int.tryParse(text);
    if (asInt != null) {
      final normalized = asInt < 1000000000000 ? asInt * 1000 : asInt;
      return DateTime.fromMillisecondsSinceEpoch(normalized);
    }

    return DateTime.tryParse(text);
  }
  if (value is Map) {
    final seconds = value['_seconds'];
    if (seconds is int) {
      final nanoseconds = value['_nanoseconds'];
      final milliseconds = seconds * 1000 +
          ((nanoseconds is int ? nanoseconds : 0) / 1000000).round();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
  }

  return null;
}
