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

    final commonData = <String, dynamic>{
      'uid': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastAuthMethod': authMethod,
      if (email.isNotEmpty) 'email': email,
      'emailVerified': user.emailVerified,
      'email_verified': user.emailVerified,
      'isEmailVerified': user.emailVerified,
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
        debugPrint('[AuthBootstrap] Unable to check users/${user.uid}: $error');
      }
    }

    final payload = <String, dynamic>{
      ...commonData,
      if (shouldCreateWithDefaults) 'createdAt': FieldValue.serverTimestamp(),
      if (shouldCreateWithDefaults) 'accountType': 'Particulier',
      if (shouldCreateWithDefaults) 'favoriteCategories': <String>[],
      if (shouldCreateWithDefaults) 'selectedFavoriteCategories': <String>[],
      if (shouldCreateWithDefaults) 'selectedFavoriteSubcategories': <String>[],
      if (shouldCreateWithDefaults) 'profileCompleteness': 0.0,
    };

    await userRef.set(payload, SetOptions(merge: true));
  }
}
