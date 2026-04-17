import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfileBootstrapService {
  UserProfileBootstrapService._();

  static Future<void> ensureUserDocument({
    required User user,
    required String authMethod,
    bool isNewUserHint = false,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final email = user.email?.trim().toLowerCase() ?? '';
    final displayName = user.displayName?.trim() ?? '';

    // Reload to get fresh emailVerified state.
    try {
      await user.reload();
    } catch (_) {
      // Best effort — offline or token expired.
    }
    final freshUser = FirebaseAuth.instance.currentUser ?? user;

    final commonData = <String, dynamic>{
      'uid': freshUser.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastAuthMethod': authMethod,
      if (email.isNotEmpty) 'email': email,
      'emailVerified': freshUser.emailVerified,
      if (displayName.isNotEmpty) 'displayName': displayName,
      if (displayName.isNotEmpty) 'pseudo': displayName,
    };

    var shouldCreateWithDefaults = isNewUserHint;

    if (!shouldCreateWithDefaults) {
      try {
        final existing = await userRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 6));
        shouldCreateWithDefaults = !existing.exists;
      } catch (error) {
        debugPrint('[AuthBootstrap] Unable to check users/${freshUser.uid}: $error');
      }
    }

    if (shouldCreateWithDefaults) {
      // New user — atomic set with all defaults.
      await userRef.set(<String, dynamic>{
        ...commonData,
        'createdAt': FieldValue.serverTimestamp(),
        'accountType': 'Particulier',
        'favoriteCategories': <String>[],
        'selectedFavoriteCategories': <String>[],
        'selectedFavoriteSubcategories': <String>[],
        'profileCompleteness': 0.0,
      });
    } else {
      // Existing user — update only known fields, remove stale aliases.
      await userRef.update(<String, dynamic>{
        ...commonData,
        'email_verified': FieldValue.delete(),
        'isEmailVerified': FieldValue.delete(),
      });
    }
  }
}
