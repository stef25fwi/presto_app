import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CookieConsentChoice {
  unknown,
  accepted,
  refused,
  customized,
}

class CookieConsentState {
  const CookieConsentState({
    required this.choice,
    required this.analyticsAllowed,
    required this.marketingAllowed,
    required this.updatedAt,
  });

  final CookieConsentChoice choice;
  final bool analyticsAllowed;
  final bool marketingAllowed;
  final DateTime? updatedAt;

  bool get hasChoice => choice != CookieConsentChoice.unknown;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'choice': choice.name,
      'analyticsAllowed': analyticsAllowed,
      'marketingAllowed': marketingAllowed,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static CookieConsentState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final choiceName = (json['choice'] ?? '').toString();
    final choice = CookieConsentChoice.values.firstWhere(
      (value) => value.name == choiceName,
      orElse: () => CookieConsentChoice.unknown,
    );

    final analyticsAllowed = json['analyticsAllowed'] == true;
    final marketingAllowed = json['marketingAllowed'] == true;
    final updatedAtRaw = json['updatedAt']?.toString();
    final updatedAt = updatedAtRaw == null || updatedAtRaw.isEmpty
        ? null
        : DateTime.tryParse(updatedAtRaw);

    if (choice == CookieConsentChoice.unknown) {
      return null;
    }

    return CookieConsentState(
      choice: choice,
      analyticsAllowed: analyticsAllowed,
      marketingAllowed: marketingAllowed,
      updatedAt: updatedAt,
    );
  }
}

class CookieConsentService extends ChangeNotifier {
  CookieConsentService._();

  static final CookieConsentService instance = CookieConsentService._();

  static const String _storageKey = 'cookie_consent_v1';
  static const Duration retentionDuration = Duration(days: 180);

  CookieConsentState? _state;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  CookieConsentState? get state => _state;

  bool get hasChoice => _state?.hasChoice ?? false;

  bool get shouldShowBanner => !hasChoice;

  bool get canUseAnalytics => _state?.analyticsAllowed ?? false;

  bool get canUseMarketing => _state?.marketingAllowed ?? false;

  DateTime? get choiceUpdatedAt => _state?.updatedAt;

  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _state = CookieConsentState.fromJson(decoded);
        } else if (decoded is Map) {
          _state = CookieConsentState.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    } catch (error) {
      debugPrint('[Consent] load failed: $error');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> acceptAll() async {
    await savePreferences(
      analyticsAllowed: true,
      marketingAllowed: true,
      choice: CookieConsentChoice.accepted,
    );
  }

  Future<void> refuseAll() async {
    await savePreferences(
      analyticsAllowed: false,
      marketingAllowed: false,
      choice: CookieConsentChoice.refused,
    );
  }

  Future<void> savePreferences({
    required bool analyticsAllowed,
    required bool marketingAllowed,
    CookieConsentChoice choice = CookieConsentChoice.customized,
  }) async {
    final normalizedChoice = choice == CookieConsentChoice.unknown
        ? CookieConsentChoice.customized
        : choice;

    _state = CookieConsentState(
      choice: normalizedChoice,
      analyticsAllowed: analyticsAllowed,
      marketingAllowed: marketingAllowed,
      updatedAt: DateTime.now().toUtc(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_state!.toJson()));
    } catch (error) {
      debugPrint('[Consent] save failed: $error');
    }

    notifyListeners();
  }
}
