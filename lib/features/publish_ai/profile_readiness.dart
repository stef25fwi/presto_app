import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../app_core.dart';

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
  }) =>
      ProfileReadinessResult._(
        isReady: false,
        gate: gate,
        missingFields: missingFields,
        user: user,
        errorDetail: errorDetail?.toString(),
      );

  final bool isReady;
  final ProfileReadinessGate? gate;
  final List<String> missingFields;
  final User? user;
  final String? errorDetail;

  /// Short, user-facing message for the blocked case.
  String describe() {
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
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const Duration _readTimeout = Duration(seconds: 6);

  /// One-shot check. Reads users/{uid} from server with a short cache
  /// fallback so the AI button stays responsive even when the network is
  /// flaky. Never throws — failures are mapped to [ProfileReadinessGate].
  Future<ProfileReadinessResult> check() async {
    final user = _auth.currentUser;
    if (user == null) {
      return ProfileReadinessResult.blocked(
        gate: ProfileReadinessGate.signedOut,
      );
    }

    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_readTimeout);
    } catch (serverError) {
      debugPrint(
        '[ProfileReadiness] server read failed uid=${user.uid} err=$serverError',
      );
      try {
        snap = await _firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache))
            .timeout(_readTimeout);
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
    const profilePath = 'users';
    final city = firstNonEmptyString(
      data,
      const ['city', 'ville', 'commune', 'locality'],
    );
    final postalCode = _resolvePostalCode(data, city);

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
      '[ProfileReadiness] profilePath=$profilePath/${user.uid} '
      'keys=${data.keys.toList()..sort()} city="$city" postalCode="$postalCode" '
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
    for (final key in aliases) {
      final raw = data[key];
      if (raw == null) continue;
      final value = raw.toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _resolvePostalCode(Map<String, dynamic> data, String city) {
    final explicitPostalCode = firstNonEmptyString(
      data,
      const ['postalCode', 'codePostal', 'zipCode', 'zipcode', 'cp'],
    );
    if (explicitPostalCode.isNotEmpty) return explicitPostalCode;
    if (city.isEmpty) return '';

    final directPostalCode = kCityPostalMap[city];
    if (directPostalCode != null && directPostalCode.trim().isNotEmpty) {
      return directPostalCode.trim();
    }

    final normalizedCity = _normalizeCity(city);
    for (final entry in kCityPostalMap.entries) {
      if (_normalizeCity(entry.key) == normalizedCity) {
        return entry.value.trim();
      }
    }
    return '';
  }

  static String _normalizeCity(String value) {
    return value.trim().toLowerCase();
  }
}
