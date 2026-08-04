// Formatage et agrégation partagés par les vues d'administration.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

Map<String, dynamic> _stringKeyMap(dynamic value) {
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return <String, dynamic>{};
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  try {
    final converted = (value as dynamic).toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    // no-op
  }
  return null;
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateKey(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

int? _bucketIndexFor(DateTime? value, DateTime start, int bucketCount) {
  if (value == null) return null;
  final normalized = _startOfDay(value);
  final diff = normalized.difference(start).inDays;
  if (diff < 0 || diff >= bucketCount) return null;
  return diff;
}

String _formatCompactNumber(num value) {
  final absValue = value.abs();
  if (absValue >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (absValue >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _formatPercent(double ratio) {
  if (!ratio.isFinite) return '—';
  final percent = ratio * 100;
  final decimals = percent >= 10 ? 0 : 1;
  return '${percent.toStringAsFixed(decimals)} %';
}

bool _isCompleteAdminUser(Map<String, dynamic> data) {
  final hasIdentity = [
    data['displayName'],
    data['pseudo'],
    data['userName'],
    data['name'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
  final hasPhone = [
    data['phone'],
    data['phoneNumber'],
    data['phone_number'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
  final hasLocation = [
    data['city'],
    data['cityId'],
    data['postalCode'],
    data['cp'],
    data['companyName'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
  final hasAvatar = [
    data['avatarUrl'],
    data['photoUrl'],
    data['photoURL'],
    data['profilePhotoUrl'],
    data['imageUrl'],
  ].any((value) => value != null && value.toString().trim().isNotEmpty);
  final score = [
    hasIdentity,
    hasPhone,
    hasLocation,
    hasAvatar,
  ].where((value) => value).length;
  return score >= 3;
}

String _topEntryLabel(Map<String, int> counts, {String fallback = '—'}) {
  String label = fallback;
  var best = -1;
  counts.forEach((key, value) {
    if (value > best && key.trim().isNotEmpty) {
      best = value;
      label = key;
    }
  });
  return label;
}

String _topSourceLabel(dynamic rawMap, {String fallback = 'à connecter'}) {
  final map = _stringKeyMap(rawMap);
  if (map.isEmpty) return fallback;
  String topLabel = fallback;
  var topValue = -1;
  map.forEach((key, value) {
    final current = _toInt(value);
    if (current > topValue && key.trim().isNotEmpty) {
      topValue = current;
      topLabel = key;
    }
  });
  return topLabel;
}

String _escapeCsv(String value) {
  final needsQuotes =
      value.contains(',') || value.contains('\n') || value.contains('"');
  final escaped = value.replaceAll('"', '""');
  return needsQuotes ? '"$escaped"' : escaped;
}

String _buildAdminDomainCsv({
  required _AdminDomainLiveData data,
  required _AdminDashboardWindow window,
}) {
  final rows = <String>['domaine,periode,type,label,valeur'];

  for (final stat in data.highlights) {
    rows.add(
      [
        data.domain.title,
        window.label,
        'highlight',
        stat.label,
        stat.value,
      ].map(_escapeCsv).join(','),
    );
  }

  for (var index = 0; index < data.series.length; index += 1) {
    rows.add(
      [
        data.domain.title,
        window.label,
        'trend_point',
        'jour_${index + 1}',
        data.series[index].toStringAsFixed(2),
      ].map(_escapeCsv).join(','),
    );
  }

  for (final metric in data.domain.metrics) {
    rows.add(
      [
        data.domain.title,
        window.label,
        'catalog_metric',
        metric,
        '',
      ].map(_escapeCsv).join(','),
    );
  }

  rows.add(
    [
      data.domain.title,
      window.label,
      'note',
      'note',
      data.note,
    ].map(_escapeCsv).join(','),
  );

  return rows.join('\n');
}

String _formatAdminTimestamp(int? millis) {
  if (millis == null || millis <= 0) return 'inconnue';
  final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
