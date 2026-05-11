import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfileBootstrapService {
  UserProfileBootstrapService._();

  static const int _maxAttempts = 3;
  static const Duration _baseBackoff = Duration(seconds: 1);

  /// Best-effort profile creation/sync after sign-in. Retries on transient
  /// failures (unavailable, deadline-exceeded, network) but does not retry
  /// permission-denied or unauthenticated, which are definitive.
  static Future<void> ensureUserDocument({
    required User user,
    required String authMethod,
    bool isNewUserHint = false,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        await _ensureUserDocumentOnce(
          user: user,
          authMethod: authMethod,
          isNewUserHint: isNewUserHint,
        );
        return;
      } on FirebaseException catch (error) {
        lastError = error;
        if (!_isRetryableFirestoreCode(error.code) ||
            attempt == _maxAttempts - 1) {
          rethrow;
        }
        final backoff = _baseBackoff * math.pow(2, attempt).toInt();
        debugPrint(
          '[AuthBootstrap] retry ${attempt + 1}/$_maxAttempts after $backoff '
          'due to code=${error.code}',
        );
        await Future<void>.delayed(backoff);
      } catch (error) {
        lastError = error;
        if (attempt == _maxAttempts - 1) {
          rethrow;
        }
        final backoff = _baseBackoff * math.pow(2, attempt).toInt();
        debugPrint(
          '[AuthBootstrap] retry ${attempt + 1}/$_maxAttempts after $backoff '
          'due to $error',
        );
        await Future<void>.delayed(backoff);
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }

  static bool _isRetryableFirestoreCode(String code) {
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'aborted':
      case 'internal':
      case 'cancelled':
      case 'resource-exhausted':
        return true;
      case 'permission-denied':
      case 'unauthenticated':
      case 'not-found':
      case 'already-exists':
      case 'invalid-argument':
      case 'failed-precondition':
        return false;
      default:
        return true;
    }
  }

  static Future<void> _ensureUserDocumentOnce({
    required User user,
    required String authMethod,
    required bool isNewUserHint,
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
