import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../app_core.dart';
import '../../services/user_profile_bootstrap_service.dart';

typedef ProfileAccessPreparer = Future<User?> Function({
  required User user,
  required bool forceRefreshAppCheckToken,
});

typedef ProfileDocumentReader =
    Future<DocumentSnapshot<Map<String, dynamic>>> Function({
  required String uid,
  required Source source,
});

/// Reasons a user is not allowed to start the AI publishing flow.
enum ProfileReadinessGate {
  /// No Firebase user — auth required.
  signedOut,

  /// The Firestore profile document is missing entirely (bootstrap pending
  /// or a transient read error). The caller can either wait and retry or
  /// route the user to the profile page.
  profileMissing,

  /// The profile document exists but some required fields are blank.
  fieldsMissing,

  /// The Firestore read failed in a way we cannot recover from in-place.
  /// The caller should surface a generic retry message.
  readFailed,
}

/// Outcome returned by [ProfileReadinessChecker.check]. The pipeline turns
/// it into either a green-light or an actionable error event.
class ProfileReadinessResult {
  const ProfileReadinessResult._({
    required this.isReady,
    this.gate,
    this.missingFields = const <String>[],
    this.user,
    this.errorDetail,
    this.messageOverride,
  });

  /// All requirements are satisfied — the caller may start the AI flow.
  factory ProfileReadinessResult.ready(User user) =>
      ProfileReadinessResult._(isReady: true, user: user);

  /// At least one requirement is unmet. See [gate] / [missingFields].
  factory ProfileReadinessResult.blocked({
    required ProfileReadinessGate gate,
    List<String> missingFields = const <String>[],
    User? user,
    Object? errorDetail,
    String? messageOverride,
  }) =>
      ProfileReadinessResult._(
        isReady: false,
        gate: gate,
        missingFields: missingFields,
        user: user,
        errorDetail: errorDetail?.toString(),
        messageOverride: messageOverride,
      );

  final bool isReady;
  final ProfileReadinessGate? gate;
  final List<String> missingFields;
  final User? user;
  final String? errorDetail;
  final String? messageOverride;

  /// Short, user-facing message for the blocked case.
  String describe() {
    final override = messageOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    switch (gate) {
      case ProfileReadinessGate.signedOut:
        return "Connecte-toi pour utiliser la dictée IA.";
      case ProfileReadinessGate.profileMissing:
        return "Ton profil n'est pas encore initialisé. Complète-le pour utiliser la dictée IA.";
      case ProfileReadinessGate.fieldsMissing:
        final friendlyNames =
            missingFields.map(_friendlyFieldLabel).toList(growable: false);
        if (friendlyNames.isEmpty) {
          return "Complète ton profil pour utiliser la dictée IA.";
        }
        return "Complète ton profil (${friendlyNames.join(', ')}) pour utiliser la dictée IA.";
      case ProfileReadinessGate.readFailed:
        return "Impossible de vérifier ton profil. Réessaie dans un instant.";
      case null:
        return "Profil prêt.";
    }
  }
}

class ProfileLocationResolution {
  const ProfileLocationResolution({
    required this.city,
    required this.citySource,
    required this.postalCode,
    required this.postalCodeSource,
  });

  final String city;
  final String? citySource;
  final String postalCode;
  final String? postalCodeSource;

  String get blockReason {
    if (city.isEmpty && postalCode.isEmpty) {
      return 'missing city and postalCode';
    }
    if (city.isEmpty) return 'missing city';
    if (postalCode.isEmpty) return 'missing postalCode';
    return 'none';
  }
}

class _ResolvedProfileField {
  const _ResolvedProfileField({
    required this.value,
    required this.source,
  });

  final String value;
  final String? source;
}

String _friendlyFieldLabel(String key) {
  switch (key) {
    case 'displayName':
      return 'pseudo';
    case 'city':
      return 'ville';
    case 'postalCode':
      return 'code postal';
    default:
      return key;
  }
}

/// Checks that the connected user has filled the minimum profile so the AI
/// pipeline can build meaningful listing drafts (and rule-compliant writes).
///
/// Required fields: a display name (or pseudo alias), a city and a postal
/// code. The check accepts the common Firestore aliases used across the
/// codebase (pseudo, displayName, postalCode, postal_code, …).
class ProfileReadinessChecker {
  ProfileReadinessChecker({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ProfileAccessPreparer? accessPreparer,
    ProfileDocumentReader? documentReader,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _accessPreparer = accessPreparer,
        _documentReader = documentReader;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ProfileAccessPreparer? _accessPreparer;
  final ProfileDocumentReader? _documentReader;

  static const Duration _readTimeout = Duration(seconds: 6);

  Future<User?> _prepareProfileAccess(User user) {
    final override = _accessPreparer;
    if (override != null) {
      return override(
        user: user,
        forceRefreshAppCheckToken: true,
      );
    }
    return UserProfileBootstrapService.prepareProfileFirestoreAccess(
      user: user,
      forceRefreshAppCheckToken: true,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _readProfileDocument({
    required String uid,
    required Source source,
  }) {
    final override = _documentReader;
    final read = override != null
        ? override(uid: uid, source: source)
        : _firestore
            .collection('users')
            .doc(uid)
            .get(GetOptions(source: source));
    return read.timeout(_readTimeout);
  }

  /// One-shot check. Reads users/{uid} from server with a short cache
  /// fallback so the AI button stays responsive even when the network is
  /// flaky. Never throws — failures are mapped to [ProfileReadinessGate].
  Future<ProfileReadinessResult> check() async {
    var user = _auth.currentUser;
    if (user == null) {
      return ProfileReadinessResult.blocked(
        gate: ProfileReadinessGate.signedOut,
      );
    }

    try {
      user = await _prepareProfileAccess(user) ?? _auth.currentUser ?? user;
    } catch (error) {
      debugPrint(
        '[ProfileReadiness] profile access preparation failed '
        'uid=${user.uid} err=$error',
      );
      return ProfileReadinessResult.blocked(
        gate: ProfileReadinessGate.readFailed,
        user: user,
        errorDetail: error,
        messageOverride:
            UserProfileBootstrapService.userFacingProfileSyncMessage(error),
      );
    }

    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await _readProfileDocument(uid: user.uid, source: Source.server);
    } catch (serverError) {
      debugPrint(
        '[ProfileReadiness] server read failed uid=${user.uid} err=$serverError',
      );
      try {
        snap = await _readProfileDocument(uid: user.uid, source: Source.cache);
      } catch (cacheError) {
        debugPrint(
          '[ProfileReadiness] cache read failed uid=${user.uid} err=$cacheError',
        );
        return ProfileReadinessResult.blocked(
          gate: ProfileReadinessGate.readFailed,
          user: user,
          errorDetail: serverError,
        );
      }
    }

    if (snap.exists != true) {
      return ProfileReadinessResult.blocked(
        gate: ProfileReadinessGate.profileMissing,
        user: user,
      );
    }

    final data = snap.data() ?? const <String, dynamic>{};
    final profilePath = 'users/${user.uid}';
    final location = resolveLocation(data);
    final city = location.city;
    final postalCode = location.postalCode;

    final missing = <String>[];
    if (firstNonEmptyString(
      data,
      const ['displayName', 'pseudo', 'name', 'username'],
    ).isEmpty) {
      // Fall back to the FirebaseAuth user.displayName so legacy accounts
      // that pre-date the Firestore migration are still allowed through.
      if ((user.displayName ?? '').trim().isEmpty) {
        missing.add('displayName');
      }
    }
    if (city.isEmpty) {
      missing.add('city');
    }
    if (postalCode.isEmpty) {
      missing.add('postalCode');
    }

    debugPrint(
      '[ProfileReadiness] profilePath=$profilePath '
      'fieldsPresent=${data.keys.toList()..sort()} '
      'resolvedCity="$city" citySource=${location.citySource ?? 'none'} '
      'resolvedPostalCode="$postalCode" '
      'postalCodeSource=${location.postalCodeSource ?? 'none'} '
      'blockReason=${missing.isEmpty ? 'none' : location.blockReason} '
      'missing=${missing.isEmpty ? 'none' : missing.join(',')}',
    );

    if (missing.isEmpty) {
      return ProfileReadinessResult.ready(user);
    }
    return ProfileReadinessResult.blocked(
      gate: ProfileReadinessGate.fieldsMissing,
      missingFields: missing,
      user: user,
    );
  }

  static String firstNonEmptyString(
    Map<String, dynamic> data,
    List<String> aliases,
  ) {
    return _firstNonEmptyStringWithSource(data, aliases).value;
  }

  static ProfileLocationResolution resolveLocation(Map<String, dynamic> data) {
    final city = _firstNonEmptyStringWithSource(
      data,
      const ['city', 'ville', 'commune', 'locality'],
    );
    final postalCode = _resolvePostalCode(data, city.value);

    return ProfileLocationResolution(
      city: city.value,
      citySource: city.source,
      postalCode: postalCode.value,
      postalCodeSource: postalCode.source,
    );
  }

  static _ResolvedProfileField _firstNonEmptyStringWithSource(
    Map<String, dynamic> data,
    List<String> aliases,
  ) {
    for (final key in aliases) {
      final raw = data[key];
      if (raw == null) continue;
      final value = raw.toString().trim();
      if (value.isNotEmpty) {
        return _ResolvedProfileField(value: value, source: key);
      }
    }
    return const _ResolvedProfileField(value: '', source: null);
  }

  static _ResolvedProfileField _resolvePostalCode(
    Map<String, dynamic> data,
    String city,
  ) {
    final explicitPostalCode = _firstNonEmptyStringWithSource(
      data,
      const [
        'postalCode',
        'codePostal',
        'zipCode',
        'zipcode',
        'cp',
        'postal_code',
        'code_postal',
      ],
    );
    if (explicitPostalCode.value.isNotEmpty) return explicitPostalCode;
    if (city.isEmpty) {
      return const _ResolvedProfileField(value: '', source: null);
    }

    final directPostalCode = kCityPostalMap[city];
    if (directPostalCode != null && directPostalCode.trim().isNotEmpty) {
      return _ResolvedProfileField(
        value: directPostalCode.trim(),
        source: 'cityPostalMap[$city]',
      );
    }

    final normalizedCity = _normalizeCity(city);
    for (final entry in kCityPostalMap.entries) {
      if (_normalizeCity(entry.key) == normalizedCity) {
        return _ResolvedProfileField(
          value: entry.value.trim(),
          source: 'cityPostalMap[${entry.key}]',
        );
      }
    }
    return const _ResolvedProfileField(value: '', source: null);
  }

  static String _normalizeCity(String value) {
    return value.trim().toLowerCase();
  }
}
