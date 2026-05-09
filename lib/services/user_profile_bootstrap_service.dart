import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfileBootstrapService {
  UserProfileBootstrapService._();

  static Future<User?> prepareProfileFirestoreAccess({
    User? user,
    bool forceRefreshToken = false,
    bool forceRefreshAppCheckToken = false,
  }) async {
    User? resolvedUser = user ?? FirebaseAuth.instance.currentUser;
    if (resolvedUser == null) {
      try {
        resolvedUser = await FirebaseAuth.instance
            .authStateChanges()
            .where((candidate) => candidate != null)
            .cast<User>()
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        resolvedUser = FirebaseAuth.instance.currentUser;
      }
    }

    if (resolvedUser == null) {
      return null;
    }

    try {
      await resolvedUser
          .getIdToken(forceRefreshToken)
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[ProfileFirestore] ID token refresh failed: $error');
      rethrow;
    }

    try {
      final appCheckToken = await FirebaseAppCheck.instance
          .getToken(forceRefreshAppCheckToken)
          .timeout(const Duration(seconds: 8));
      if ((appCheckToken ?? '').trim().isEmpty) {
        throw StateError('Jeton App Check absent pour Firestore profil.');
      }
    } catch (error) {
      debugPrint('[ProfileFirestore] App Check token refresh failed: $error');
      rethrow;
    }

    return FirebaseAuth.instance.currentUser ?? resolvedUser;
  }

  static Future<void> ensureUserDocument({
    required User user,
    required String authMethod,
    bool isNewUserHint = false,
  }) async {
    // Reload to get fresh emailVerified state.
    try {
      await user.reload();
    } catch (_) {
      // Best effort — offline or token expired.
    }
    final freshUser = await prepareProfileFirestoreAccess(
          user: FirebaseAuth.instance.currentUser ?? user,
          forceRefreshToken: true,
          forceRefreshAppCheckToken: true,
        ) ??
        FirebaseAuth.instance.currentUser ??
        user;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(freshUser.uid);
    final email = freshUser.email?.trim().toLowerCase() ?? '';
    final displayName = freshUser.displayName?.trim() ?? '';

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

    // Probe existence: try server then cache. If both fail (offline, App
    // Check, timeout) we stay with "existence unknown" and use a safe
    // merge-set so we never throw NOT_FOUND on update().
    bool? docExists;
    if (!isNewUserHint) {
      try {
        final existing = await userRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 6));
        docExists = existing.exists;
      } catch (serverError) {
        debugPrint(
          '[AuthBootstrap] server probe failed for users/${freshUser.uid}: $serverError',
        );
        try {
          final cached = await userRef
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 3));
          docExists = cached.exists;
        } catch (cacheError) {
          debugPrint(
            '[AuthBootstrap] cache probe failed for users/${freshUser.uid}: $cacheError',
          );
        }
      }
    }

    final shouldCreateWithDefaults = isNewUserHint || docExists == false;

    if (shouldCreateWithDefaults) {
      // Fresh profile — atomic set with all defaults. Safe if the doc
      // already exists thanks to merge:true (just refreshes the fields).
      await userRef.set(<String, dynamic>{
        ...commonData,
        'createdAt': FieldValue.serverTimestamp(),
        'accountType': 'Particulier',
        'favoriteCategories': <String>[],
        'selectedFavoriteCategories': <String>[],
        'selectedFavoriteSubcategories': <String>[],
        'profileCompleteness': 0.0,
      }, SetOptions(merge: true));
      return;
    }

    if (docExists == true) {
      // Doc confirmed present — update only known fields and prune stale
      // aliases produced by older builds.
      await userRef.update(<String, dynamic>{
        ...commonData,
        'email_verified': FieldValue.delete(),
        'isEmailVerified': FieldValue.delete(),
      });
      return;
    }

    // Existence unknown (probes failed). Use merge-set to avoid NOT_FOUND.
    // Stale alias cleanup is skipped on this path to keep the write safe;
    // the next successful login will handle it.
    await userRef.set(commonData, SetOptions(merge: true));
  }
}
