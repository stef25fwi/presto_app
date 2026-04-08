import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_access_state.dart';
import 'firebase_functions_region.dart';

class AdminAccessResolver {
  AdminAccessResolver({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? prestoFirebaseFunctions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static const Duration _authRestoreTimeout = Duration(seconds: 2);
  static const Duration _documentServerTimeout = Duration(seconds: 5);
  static const Duration _documentCacheTimeout = Duration(seconds: 3);
  static const Duration _serverTimeout = Duration(seconds: 15);

  Future<AdminAccessState> resolveAdminAccess({
    bool forceRefresh = false,
  }) async {
    var state = _step(
      AdminAccessState.initial(),
      '[AdminResolver] started forceRefresh=$forceRefresh',
      stage: 'start',
    );

    var user = _auth.currentUser;
    if (user == null) {
      try {
        user = await _auth.authStateChanges().first.timeout(
              _authRestoreTimeout,
              onTimeout: () => null,
            );
      } catch (_) {}
    }

    if (user == null) {
      return _finalize(
        _step(
          state.copyWith(
            isAuthenticated: false,
            effectiveIsAdmin: false,
            sourceOfTruth: 'none',
          ),
          '[AdminResolver] no authenticated user',
          stage: 'no-auth-user',
        ),
      );
    }

    if (forceRefresh) {
      try {
        await user.reload();
      } catch (error) {
        debugPrint('[AdminResolver] auth reload skipped: $error');
      }
      user = _auth.currentUser ?? user;
    }

    state = _step(
      state.copyWith(
        isAuthenticated: true,
        uid: user.uid,
        email: user.email,
      ),
      '[AdminResolver] auth user loaded uid=${user.uid} email=${user.email ?? ''}',
      stage: 'auth-user-loaded',
    );

    IdTokenResult? tokenResult;
    try {
      tokenResult = await user.getIdTokenResult(forceRefresh);
      final claims = tokenResult.claims ?? const <String, dynamic>{};
      final tokenRoles = _rolesFromValue(claims['roles']);
      final tokenPrimaryRole = _normalizedText(claims['primaryRole']);
      final tokenHasAdmin = _hasAdminAccess(
        claims,
        roles: tokenRoles,
        primaryRole: tokenPrimaryRole,
      );

      state = _step(
        state.copyWith(
          tokenLoaded: true,
          tokenHasAdmin: tokenHasAdmin,
          tokenRoles: tokenRoles,
          tokenPrimaryRole: tokenPrimaryRole,
        ),
        '[AdminResolver] token loaded claims admin=$tokenHasAdmin roles=$tokenRoles',
        stage: 'token-loaded',
      );
    } catch (error) {
      state = _step(
        state.copyWith(tokenLoaded: false),
        '[AdminResolver] token load failed error=$error',
        stage: 'token-load-error',
      );
    }

    final userDocFuture = _getDocumentWithFallback('users', user.uid);
    final adminDocFuture = _getDocumentWithFallback('admins', user.uid);
    final docs = await Future.wait([userDocFuture, adminDocFuture]);

    final userSnap = docs[0];
    final adminSnap = docs[1];
    final profileData = userSnap?.data();
    final profileRoles = _rolesFromValue(profileData?['roles']);
    final profilePrimaryRole = _normalizedText(profileData?['primaryRole']);
    final profileHasAdmin = _hasAdminAccess(
      profileData,
      roles: profileRoles,
      primaryRole: profilePrimaryRole,
    );
    final adminDocHasAdmin = adminSnap != null &&
        adminSnap.exists &&
        ((adminSnap.data()?['enabled'] ?? true) != false);

    state = _step(
      state.copyWith(
        profileLoaded: true,
        profileHasAdmin: profileHasAdmin,
        profileRoles: profileRoles,
        profilePrimaryRole: profilePrimaryRole,
        adminDocLoaded: adminSnap != null,
        adminDocHasAdmin: adminDocHasAdmin,
      ),
      '[AdminResolver] profile loaded admin=$profileHasAdmin roles=$profileRoles adminDoc=$adminDocHasAdmin',
      stage: userSnap == null || !userSnap.exists
          ? 'user-doc-missing'
          : 'profile-loaded',
    );

    if (state.tokenHasAdmin && !state.profileHasAdmin && tokenResult != null) {
      state = _step(
        state,
        '[AdminResolver] mismatch token/profile detected',
        stage: 'profile-token-mismatch',
      );
      await syncUserRoleFromClaimsIfNeeded(user, tokenResult, state: state);
    }

    state = await _verifyServerAccess(user, state);
    return _finalize(state);
  }

  Future<void> syncUserRoleFromClaimsIfNeeded(
    User user,
    IdTokenResult tokenResult, {
    AdminAccessState? state,
  }) async {
    final claims = tokenResult.claims ?? const <String, dynamic>{};
    final tokenRoles = _rolesFromValue(claims['roles']);
    final tokenPrimaryRole = _normalizedText(claims['primaryRole']);
    final tokenHasAdmin = _hasAdminAccess(
      claims,
      roles: tokenRoles,
      primaryRole: tokenPrimaryRole,
    );
    if (!tokenHasAdmin) {
      return;
    }

    if (state?.profileHasAdmin == true) {
      return;
    }

    debugPrint('[AdminResolver] sync requested for uid=${user.uid} but client role sync is disabled');
  }

  Future<AdminAccessState> _verifyServerAccess(
    User user,
    AdminAccessState state,
  ) async {
    state = _step(
      state.copyWith(serverCheckAttempted: true),
      '[AdminResolver] server verification started',
      stage: 'server-access-start',
    );

    final callable = _functions.httpsCallable(
      'getMyAdminAccessStatus',
      options: HttpsCallableOptions(timeout: _serverTimeout),
    );

    Future<AdminAccessState> runAttempt(bool retrying) async {
      try {
        final response = await callable.call<dynamic>({});
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        final isAdmin = data['isAdmin'] == true;
        final serverSource = _normalizedText(data['source']);
        final checkedAt = _dateTimeFromMilliseconds(data['checkedAt']);
        final debugData = data['debug'] is Map
            ? Map<String, dynamic>.from(data['debug'] as Map)
            : const <String, dynamic>{};

        return _step(
          state.copyWith(
            serverCheckAttempted: true,
            serverCheckSucceeded: true,
            serverIsAdmin: isAdmin,
            serverSource: serverSource,
            serverCheckedAt: checkedAt ?? DateTime.now(),
            serverErrorCode: null,
            serverErrorMessage: null,
            serverDebug: debugData,
          ),
          '[AdminResolver] server verification success isAdmin=$isAdmin source=${serverSource ?? ''}',
          stage: 'server-access-ok',
        );
      } on FirebaseFunctionsException catch (error) {
        if (!retrying && error.code == 'unauthenticated') {
          debugPrint('[AdminResolver] server verification failed unauthenticated');
          debugPrint('[AdminResolver] retrying server verification after token refresh');
          try {
            await user.getIdToken(true);
          } catch (_) {}
          final refreshedUser = _auth.currentUser ?? user;
          return _step(
            await _verifyServerAccessRetry(callable, refreshedUser, state),
            '[AdminResolver] retry completed after token refresh',
          );
        }

        return _step(
          state.copyWith(
            serverCheckAttempted: true,
            serverCheckSucceeded: false,
            clearServerIsAdmin: true,
            serverErrorCode: error.code,
            serverErrorMessage: error.message,
          ),
          '[AdminResolver] server verification failed ${error.code}',
          stage: 'server-access-error',
        );
      } catch (error) {
        return _step(
          state.copyWith(
            serverCheckAttempted: true,
            serverCheckSucceeded: false,
            clearServerIsAdmin: true,
            serverErrorCode: 'unknown',
            serverErrorMessage: error.toString(),
          ),
          '[AdminResolver] server verification failed unknown error=$error',
          stage: 'server-access-error',
        );
      }
    }

    return runAttempt(false);
  }

  Future<AdminAccessState> _verifyServerAccessRetry(
    HttpsCallable callable,
    User user,
    AdminAccessState state,
  ) async {
    try {
      final response = await callable.call<dynamic>({});
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final isAdmin = data['isAdmin'] == true;
      final serverSource = _normalizedText(data['source']);
      final checkedAt = _dateTimeFromMilliseconds(data['checkedAt']);
      final debugData = data['debug'] is Map
          ? Map<String, dynamic>.from(data['debug'] as Map)
          : const <String, dynamic>{};
      return _step(
        state.copyWith(
          uid: user.uid,
          email: user.email,
          serverCheckAttempted: true,
          serverCheckSucceeded: true,
          serverIsAdmin: isAdmin,
          serverSource: serverSource,
          serverCheckedAt: checkedAt ?? DateTime.now(),
          serverErrorCode: null,
          serverErrorMessage: null,
          serverDebug: debugData,
        ),
        '[AdminResolver] server verification success after retry isAdmin=$isAdmin source=${serverSource ?? ''}',
        stage: 'server-access-ok',
      );
    } on FirebaseFunctionsException catch (error) {
      return _step(
        state.copyWith(
          uid: user.uid,
          email: user.email,
          serverCheckAttempted: true,
          serverCheckSucceeded: false,
          clearServerIsAdmin: true,
          serverErrorCode: error.code,
          serverErrorMessage: error.message,
        ),
        '[AdminResolver] server verification retry failed ${error.code}',
        stage: 'server-access-error',
      );
    } catch (error) {
      return _step(
        state.copyWith(
          uid: user.uid,
          email: user.email,
          serverCheckAttempted: true,
          serverCheckSucceeded: false,
          clearServerIsAdmin: true,
          serverErrorCode: 'unknown',
          serverErrorMessage: error.toString(),
        ),
        '[AdminResolver] server verification retry failed unknown error=$error',
        stage: 'server-access-error',
      );
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getDocumentWithFallback(
    String collection,
    String docId,
  ) async {
    final reference = _firestore.collection(collection).doc(docId);
    try {
      return await reference
          .get(const GetOptions(source: Source.server))
          .timeout(_documentServerTimeout);
    } catch (error) {
      debugPrint('[AdminResolver] $collection/$docId server read fallback: $error');
      try {
        return await reference
            .get(const GetOptions(source: Source.cache))
            .timeout(_documentCacheTimeout);
      } catch (cacheError) {
        debugPrint('[AdminResolver] $collection/$docId cache read failed: $cacheError');
        return null;
      }
    }
  }

  AdminAccessState _finalize(AdminAccessState state) {
    final sources = <String>[];
    if (state.tokenHasAdmin) {
      sources.add('token');
    }
    if (state.profileHasAdmin) {
      sources.add('profile');
    }
    if (state.adminDocHasAdmin) {
      sources.add('adminDoc');
    }
    if (state.serverIsAdmin == true) {
      sources.add('server');
    }

    final effectiveIsAdmin = sources.isNotEmpty;
    final finalized = _step(
      state.copyWith(
        effectiveIsAdmin: effectiveIsAdmin,
        sourceOfTruth: effectiveIsAdmin ? sources.join('+') : 'none',
      ),
      '[AdminResolver] effectiveIsAdmin=$effectiveIsAdmin source=${effectiveIsAdmin ? sources.join('+') : 'none'}',
      stage: 'finished',
    );
    debugPrint('[AdminResolver] finished');
    return finalized;
  }

  AdminAccessState _step(
    AdminAccessState state,
    String message, {
    String? stage,
  }) {
    debugPrint(message);
    return state.copyWith(
      lastStage: stage ?? state.lastStage,
      debugSteps: <String>[...state.debugSteps, message],
    );
  }

  List<String> _rolesFromValue(dynamic value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((entry) => entry.toString().trim().toLowerCase())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  bool _hasAdminAccess(
    Map<String, dynamic>? data, {
    required List<String> roles,
    required String? primaryRole,
  }) {
    if (roles.contains('admin') || roles.contains('superadmin')) {
      return true;
    }
    if (primaryRole == 'admin' || primaryRole == 'superadmin') {
      return true;
    }
    return data?['admin'] == true || data?['superadmin'] == true;
  }

  String? _normalizedText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text.toLowerCase();
  }

  DateTime? _dateTimeFromMilliseconds(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}