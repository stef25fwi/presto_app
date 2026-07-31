import 'package:flutter/widgets.dart' show Alignment;
import 'package:cloud_firestore/cloud_firestore.dart';

class HeroSlide {
  final String id;
  final String title;
  final String mediaUrl;
  final String storagePath;
  final String mediaType;
  final int durationSeconds;
  final int order;
  final bool isActive;
  final bool isFirst;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String scope;
  final List<String> targetRegions;

  /// Point focal de recadrage, en fractions [0.0, 1.0] de la largeur/hauteur
  /// de l'image (0.5, 0.5 = centre). Permet de garder le sujet/texte
  /// important visible quand `BoxFit.cover` rogne l'image sur les écrans
  /// étroits (mobile web).
  final double focalX;
  final double focalY;

  const HeroSlide({
    required this.id,
    required this.title,
    required this.mediaUrl,
    required this.storagePath,
    required this.mediaType,
    required this.durationSeconds,
    required this.order,
    required this.isActive,
    required this.isFirst,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.scope = 'global',
    this.targetRegions = const [],
    this.focalX = 0.5,
    this.focalY = 0.5,
  });

  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
  bool get isGlobal => scope == 'global';
  bool get isRegional => scope == 'regional';

  /// Alignement Flutter correspondant au point focal, utilisable directement
  /// avec `BoxFit.cover` (Image, FittedBox...).
  Alignment get focalAlignment => Alignment(
        focalX.clamp(0.0, 1.0).toDouble() * 2 - 1,
        focalY.clamp(0.0, 1.0).toDouble() * 2 - 1,
      );

  factory HeroSlide.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return HeroSlide.fromMap(snapshot.id, data);
  }

  factory HeroSlide.fromMap(String id, Map<String, dynamic> data) {
    final mediaType = _readText(data, const ['mediaType']).toLowerCase();
    final rawScope = _readText(data, const ['scope']);
    return HeroSlide(
      id: id,
      title: _readText(data, const ['title']),
      mediaUrl: _readText(data, const ['mediaUrl']),
      storagePath: _readText(data, const ['storagePath']),
      mediaType: mediaType == 'video' ? 'video' : 'image',
      durationSeconds: _readInt(data, const ['durationSeconds'], fallback: 5),
      order: _readInt(data, const ['order']),
      isActive: _readBool(data, const ['isActive'], fallback: true),
      isFirst: _readBool(data, const ['isFirst']),
      createdAt: _readDateTime(data, const ['createdAt']),
      updatedAt: _readDateTime(data, const ['updatedAt']),
      createdBy: _readNullableText(data, const ['createdBy']),
      scope: rawScope == 'regional' ? 'regional' : 'global',
      targetRegions: (data['targetRegions'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      focalX: _readDouble(data, const ['focalX'], fallback: 0.5),
      focalY: _readDouble(data, const ['focalY'], fallback: 0.5),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'mediaUrl': mediaUrl,
      'storagePath': storagePath,
      'mediaType': mediaType,
      'durationSeconds': durationSeconds,
      'order': order,
      'isActive': isActive,
      'isFirst': isFirst,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'createdBy': createdBy,
      'scope': scope,
      'targetRegions': targetRegions,
      'focalX': focalX,
      'focalY': focalY,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'mediaUrl': mediaUrl,
      'storagePath': storagePath,
      'mediaType': mediaType,
      'durationSeconds': durationSeconds,
      'order': order,
      'isActive': isActive,
      'isFirst': isFirst,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
      'scope': scope,
      'targetRegions': targetRegions,
      'focalX': focalX,
      'focalY': focalY,
    };
  }

  HeroSlide copyWith({
    String? id,
    String? title,
    String? mediaUrl,
    String? storagePath,
    String? mediaType,
    int? durationSeconds,
    int? order,
    bool? isActive,
    bool? isFirst,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? scope,
    List<String>? targetRegions,
    double? focalX,
    double? focalY,
  }) {
    return HeroSlide(
      id: id ?? this.id,
      title: title ?? this.title,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      storagePath: storagePath ?? this.storagePath,
      mediaType: mediaType ?? this.mediaType,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      isFirst: isFirst ?? this.isFirst,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      scope: scope ?? this.scope,
      targetRegions: targetRegions ?? this.targetRegions,
      focalX: focalX ?? this.focalX,
      focalY: focalY ?? this.focalY,
    );
  }

  static int compareDisplayOrder(HeroSlide left, HeroSlide right) {
    if (left.isFirst != right.isFirst) {
      return left.isFirst ? -1 : 1;
    }
    final orderComparison = left.order.compareTo(right.order);
    if (orderComparison != 0) {
      return orderComparison;
    }
    return left.id.compareTo(right.id);
  }

  static String _readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String? _readNullableText(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final value = _readText(data, keys);
    return value.isEmpty ? null : value;
  }

  static int _readInt(
    Map<String, dynamic> data,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  static bool _readBool(
    Map<String, dynamic> data,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) {
        return value;
      }
      final normalized = value?.toString().trim().toLowerCase() ?? '';
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return fallback;
  }

  static double _readDouble(
    Map<String, dynamic> data,
    List<String> keys, {
    double fallback = 0.0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) {
        return value.toDouble().clamp(0.0, 1.0).toDouble();
      }
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed.clamp(0.0, 1.0).toDouble();
      }
    }
    return fallback;
  }

  static DateTime? _readDateTime(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}
