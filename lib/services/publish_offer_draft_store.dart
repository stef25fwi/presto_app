import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brouillon local de publication.
///
/// Les données sont rattachées à un compte, supprimées lors d'un changement
/// de compte et expirent automatiquement. Les photos restent hors de ce
/// stockage : leurs chemins temporaires ne sont pas fiables après un
/// rechargement Web ou mobile.
@immutable
class PublishOfferDraft {
  const PublishOfferDraft({
    required this.ownerId,
    required this.savedAt,
    this.title = '',
    this.description = '',
    this.city = '',
    this.postalCode = '',
    this.phone = '',
    this.phoneCountryCode = '+33',
    this.category,
    this.subcategory,
    this.missionDelay,
    this.budgetType = 'Fixe',
    this.budget = '',
    this.hidePhone = false,
  });

  static const int schemaVersion = 1;

  final String ownerId;
  final DateTime savedAt;
  final String title;
  final String description;
  final String city;
  final String postalCode;
  final String phone;
  final String phoneCountryCode;
  final String? category;
  final String? subcategory;
  final String? missionDelay;
  final String budgetType;
  final String budget;
  final bool hidePhone;

  bool get hasMeaningfulContent =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      city.trim().isNotEmpty ||
      postalCode.trim().isNotEmpty ||
      phone.trim().isNotEmpty ||
      (category ?? '').trim().isNotEmpty ||
      (subcategory ?? '').trim().isNotEmpty ||
      (missionDelay ?? '').trim().isNotEmpty ||
      budget.trim().isNotEmpty ||
      budgetType != 'Fixe' ||
      hidePhone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': schemaVersion,
        'ownerId': ownerId,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'title': _bounded(title, 180),
        'description': _bounded(description, 6000),
        'city': _bounded(city, 180),
        'postalCode': _bounded(postalCode, 20),
        'phone': _bounded(phone, 40),
        'phoneCountryCode': _bounded(phoneCountryCode, 8),
        'category': _boundedNullable(category, 120),
        'subcategory': _boundedNullable(subcategory, 160),
        'missionDelay': _boundedNullable(missionDelay, 80),
        'budgetType': _bounded(budgetType, 40),
        'budget': _bounded(budget, 40),
        'hidePhone': hidePhone,
      };

  static PublishOfferDraft? fromJson(
    Map<String, dynamic> json, {
    required String expectedOwnerId,
  }) {
    if (json['version'] != schemaVersion) return null;
    final ownerId = _string(json['ownerId'], 160);
    if (ownerId != expectedOwnerId) return null;

    final savedAt = DateTime.tryParse(_string(json['savedAt'], 80));
    if (savedAt == null) return null;

    return PublishOfferDraft(
      ownerId: ownerId,
      savedAt: savedAt.toUtc(),
      title: _string(json['title'], 180),
      description: _string(json['description'], 6000),
      city: _string(json['city'], 180),
      postalCode: _string(json['postalCode'], 20),
      phone: _string(json['phone'], 40),
      phoneCountryCode: _string(json['phoneCountryCode'], 8, fallback: '+33'),
      category: _nullableString(json['category'], 120),
      subcategory: _nullableString(json['subcategory'], 160),
      missionDelay: _nullableString(json['missionDelay'], 80),
      budgetType: _string(json['budgetType'], 40, fallback: 'Fixe'),
      budget: _string(json['budget'], 40),
      hidePhone: json['hidePhone'] == true,
    );
  }

  static String _bounded(String value, int maximumLength) {
    return value.length <= maximumLength
        ? value
        : value.substring(0, maximumLength);
  }

  static String? _boundedNullable(String? value, int maximumLength) {
    if (value == null) return null;
    return _bounded(value, maximumLength);
  }

  static String _string(
    Object? value,
    int maximumLength, {
    String fallback = '',
  }) {
    if (value is! String) return fallback;
    return _bounded(value, maximumLength);
  }

  static String? _nullableString(Object? value, int maximumLength) {
    if (value is! String) return null;
    final bounded = _bounded(value, maximumLength);
    return bounded.trim().isEmpty ? null : bounded;
  }
}

class PublishOfferDraftStore {
  PublishOfferDraftStore({
    DateTime Function()? now,
    this.retention = const Duration(days: 7),
  }) : _now = now ?? DateTime.now;

  static final PublishOfferDraftStore instance = PublishOfferDraftStore();

  static const String _keyPrefix = 'publish_offer_draft.v1.';
  final DateTime Function() _now;
  final Duration retention;

  Future<void> save(PublishOfferDraft draft) async {
    final ownerId = draft.ownerId.trim();
    if (ownerId.isEmpty) return;

    final preferences = await SharedPreferences.getInstance();
    await _purgeOtherOwners(preferences, ownerId);
    final key = _keyFor(ownerId);
    if (!draft.hasMeaningfulContent) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(key, jsonEncode(draft.toJson()));
  }

  Future<PublishOfferDraft?> loadForOwner(String rawOwnerId) async {
    final ownerId = rawOwnerId.trim();
    if (ownerId.isEmpty) return null;

    final preferences = await SharedPreferences.getInstance();
    await _purgeOtherOwners(preferences, ownerId);
    final key = _keyFor(ownerId);
    final raw = preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;

    PublishOfferDraft? draft;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        draft = PublishOfferDraft.fromJson(
          Map<String, dynamic>.from(decoded),
          expectedOwnerId: ownerId,
        );
      }
    } catch (_) {
      draft = null;
    }

    if (draft == null || _isExpired(draft.savedAt)) {
      await preferences.remove(key);
      return null;
    }
    return draft;
  }

  Future<void> clearForOwner(String rawOwnerId) async {
    final ownerId = rawOwnerId.trim();
    if (ownerId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_keyFor(ownerId));
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    final draftKeys = preferences
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .toList(growable: false);
    for (final key in draftKeys) {
      await preferences.remove(key);
    }
  }

  bool _isExpired(DateTime savedAt) {
    final age = _now().toUtc().difference(savedAt.toUtc());
    return age.isNegative || age > retention;
  }

  Future<void> _purgeOtherOwners(
    SharedPreferences preferences,
    String ownerId,
  ) async {
    final activeKey = _keyFor(ownerId);
    final staleKeys = preferences
        .getKeys()
        .where(
          (key) => key.startsWith(_keyPrefix) && key != activeKey,
        )
        .toList(growable: false);
    for (final key in staleKeys) {
      await preferences.remove(key);
    }
  }

  static String _keyFor(String ownerId) {
    return '$_keyPrefix${Uri.encodeComponent(ownerId)}';
  }
}
