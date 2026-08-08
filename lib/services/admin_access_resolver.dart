import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/admin_access_state.dart';
import 'admin_access_policy.dart';
import 'firebase_functions_region.dart';

class AdminAccessResolver {
  AdminAccessResolver({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _injectedAuth = auth,
        _injectedFirestore = firestore,
        _injectedFunctions = functions;

  final FirebaseAuth? _injectedAuth;
  final FirebaseFirestore? _injectedFirestore;
  final FirebaseFunctions? _injectedFunctions;

  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _injectedFunctions ?? prestoFirebaseFunctions;

  static const Duration _authRestoreTimeout = Duration(seconds: 2);
  static const Duration _authRebindTimeout = Duration(seconds: 2);
  static const Duration _documentServerTimeout = Duration(seconds: 5);
  static const Duration _documentCacheTimeout = Duration(seconds: 3);
  static const Duration _serverTimeout = Duration(seconds: 15);
  static const String _adminAccessCallableName = 'getMyAdminAccessStatus';
  static const AdminAccessPolicy _accessPolicy = AdminAccessPolicy();

  Future<AdminAccessState> resolveAdminAccess({
    bool forceRefresh = false,
    bool returnOnLocalAdminEvidence = false,
  }) async {
    _diag(
      'start forceRefresh=$forceRefresh '
      'userNull=${_auth.currentUser == null} '
      'project=${_firebaseProjectId()} '
      'region=$kFirebaseFunctionsRegion '
      'function=$_adminAccessCallableName '
      'callType=callable',
    );

    var state = _step(
      AdminAccessState.initial(),
      '[AdminResolver] started forceRefresh=$forceRefresh',
      stage: 'start',
    );

    var user = _auth.currentUser;
    if (user == null) {
      _diag(
        'auth currentUser is null, waiting authStateChanges '
        'timeout=${_authRestoreTimeout.inSeconds}s',
      );
      try {
        user = await _auth
            .authStateChanges()
            .firstWhere((candidate) => candidate != null)
            .timeout(_authRestoreTimeout, onTimeout: () => null);
      } catch (e) {
        _diag('authStateChanges error: $e');
      }
    }

    if (user == null) {
      _diag('auth user resolved: null');
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
    }
    // Freeze the user reference — do not re-read _auth.currentUser after
    // this point to avoid TOCTOU race.
    final resolvedUser = _auth.currentUser ?? user;

    state = _step(
      state.copyWith(
        isAuthenticated: true,
        uid: resolvedUser.uid,
        email: resolvedUser.email,
      ),
      '[AdminResolver] auth user loaded uid=${resolvedUser.uid} email=${resolvedUser.email ?? ''}',
      stage: 'auth-user-loaded',
    );
    _diag(
      'auth user resolved uid=${resolvedUser.uid} email=${resolvedUser.email ?? ''} '
      'userNull=${_auth.currentUser == null}',
    );

    IdTokenResult? tokenResult;
    try {
      final token = await resolvedUser.getIdToken(forceRefresh);
      _diag(
        'token getIdToken($forceRefresh)=ok len=${(token ?? '').length} '
        'preview=${_tokenPreview(token)}',
      );

      tokenResult = await resolvedUser.getIdTokenResult(forceRefresh);
      final claims = tokenResult.claims ?? const <String, dynamic>{};
      final tokenRoles = _rolesFromValue(claims['roles']);
      final tokenPrimaryRole = _firstNormalizedText(claims, const [
        'primaryRole',
        'role',
        'adminRole',
      ]);
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
      _diag(
        'token roles=$tokenRoles primaryRole=${tokenPrimaryRole ?? '-'} '
        'tokenHasAdmin=$tokenHasAdmin',
      );
      if (returnOnLocalAdminEvidence && tokenHasAdmin) {
        return _finalize(
          _step(
            state,
            '[AdminResolver] returning after local token admin evidence',
            stage: 'local-token-admin',
          ),
        );
      }
    } catch (error) {
      _diag('token loading failed error=$error');
      state = _step(
        state.copyWith(tokenLoaded: false),
        '[AdminResolver] token load failed error=$error',
        stage: 'token-load-error',
      );
    }

    _diag(
      'firestore profilePath=users/${resolvedUser.uid} adminPath=admins/${resolvedUser.uid}',
    );

    final userSnap = await _getDocumentWithFallback('users', resolvedUser.uid);
    final profileData = userSnap?.data();
    final profileRoles = _rolesFromValue(profileData?['roles']);
    final profilePrimaryRole = _firstNormalizedText(profileData, const [
      'primaryRole',
      'role',
      'adminRole',
    ]);
    final profileHasAdmin = _hasAdminAccess(
      profileData,
      roles: profileRoles,
      primaryRole: profilePrimaryRole,
    );

    // admins/{uid} is server-only in firestore.rules, do not treat client
    // reads as a reliable source of truth for admin access.
    const adminDocLoaded = false;
    const adminDocHasAdmin = false;

    state = _step(
      state.copyWith(
        profileLoaded: true,
        profileHasAdmin: profileHasAdmin,
        profileRoles: profileRoles,
        profilePrimaryRole: profilePrimaryRole,
        adminDocLoaded: adminDocLoaded,
        adminDocHasAdmin: adminDocHasAdmin,
      ),
      '[AdminResolver] profile loaded admin=$profileHasAdmin roles=$profileRoles adminDoc=$adminDocHasAdmin',
      stage: userSnap == null || !userSnap.exists
          ? 'user-doc-missing'
          : 'profile-loaded',
    );
    _diag(
      'firestore profileLoaded=${userSnap?.exists == true} '
      'profileHasAdmin=$profileHasAdmin '
      'profileRoles=$profileRoles '
      'profilePrimaryRole=${profilePrimaryRole ?? '-'} '
      'adminDocLoaded=$adminDocLoaded '
      'adminDocHasAdmin=$adminDocHasAdmin',
    );

    if (returnOnLocalAdminEvidence && state.hasLocalAdminEvidence) {
      return _finalize(
        _step(
          state,
          '[AdminResolver] returning after local profile admin evidence',
          stage: 'local-profile-admin',
        ),
      );
    }

    if (state.tokenHasAdmin && !state.profileHasAdmin && tokenResult != null) {
      state = _step(
        state,
        '[AdminResolver] mismatch token/profile detected',
        stage: 'profile-token-mismatch',
      );
      state = await syncUserRoleFromClaimsIfNeeded(
        resolvedUser,
        tokenResult,
        state: state,
      );
    }

    state = await _verifyServerAccess(resolvedUser, state);

    // Stale-claims mitigation: the callable trusts the decoded ID token. If
    // admin roles were just granted (custom claims, users doc) but the local
    // token is still the pre-grant one, the server can legitimately answer
    // isAdmin=false while local evidence says admin. Force a hard token
    // refresh and retry once; if it still fails, surface a dedicated code so
    // the UI can prompt a reconnect instead of silently hiding the tile.
    if (state.serverCheckSucceeded &&
        state.serverIsAdmin == false &&
        (state.tokenHasAdmin || state.profileHasAdmin)) {
      _diag(
        'stale-claims suspected tokenHasAdmin=${state.tokenHasAdmin} '
        'profileHasAdmin=${state.profileHasAdmin} — forcing token refresh and retrying',
      );
      try {
        await resolvedUser.getIdToken(true);
        final refreshed = await resolvedUser.getIdTokenResult(true);
        final claims = refreshed.claims ?? const <String, dynamic>{};
        final refreshedRoles = _rolesFromValue(claims['roles']);
        final refreshedPrimaryRole = _firstNormalizedText(claims, const [
          'primaryRole',
          'role',
          'adminRole',
        ]);
        final refreshedTokenHasAdmin = _hasAdminAccess(
          claims,
          roles: refreshedRoles,
          primaryRole: refreshedPrimaryRole,
        );
        state = _step(
          state.copyWith(
            tokenLoaded: true,
            tokenHasAdmin: refreshedTokenHasAdmin,
            tokenRoles: refreshedRoles,
            tokenPrimaryRole: refreshedPrimaryRole,
          ),
          '[AdminResolver] token hard-refreshed for stale-claims retry tokenHasAdmin=$refreshedTokenHasAdmin',
          stage: 'stale-claims-token-refresh',
        );
        state = await _verifyServerAccess(resolvedUser, state);
        if (state.serverCheckSucceeded && state.serverIsAdmin == false) {
          state = _step(
            state.copyWith(
              serverErrorCode: 'stale-claims',
              serverErrorMessage:
                  "Tes droits admin ont été mis à jour. Reconnecte-toi pour activer l'accès.",
            ),
            '[AdminResolver] stale-claims persists after token refresh',
            stage: 'stale-claims',
          );
        }
      } catch (error) {
        _diag('stale-claims retry failed error=$error');
      }
    }

    return _finalize(state);
  }

  Future<AdminAccessState> syncUserRoleFromClaimsIfNeeded(
    User user,
    IdTokenResult tokenResult, {
    AdminAccessState? state,
  }) async {
    final claims = tokenResult.claims ?? const <String, dynamic>{};
    final tokenRoles = _rolesFromValue(claims['roles']);
    final tokenPrimaryRole = _firstNormalizedText(claims, const [
      'primaryRole',
      'role',
      'adminRole',
    ]);
    final tokenHasAdmin = _hasAdminAccess(
      claims,
      roles: tokenRoles,
      primaryRole: tokenPrimaryRole,
    );
    if (!tokenHasAdmin) {
      return state ?? AdminAccessState.initial();
    }

    if (state?.profileHasAdmin == true) {
      return state!;
    }

    // Role / admin fields on users/{uid} are blacklisted for client writes by
    // Firestore rules. The canonical role propagation now happens in the
    // server-side trigger functions/src/modules/auth/role_claims_sync.ts
    // (onUserRolesChanged): any admin write to users/{uid} via Admin SDK or
    // Firebase Console is mirrored into custom claims, and getMyAdminAccessStatus
    // trusts those claims. Attempting a client write here would silently fail
    // with PERMISSION_DENIED, so we only record the in-memory evidence so the
    // resolver finalize can prefer the token-only path.
    final normalizedRoles =
        tokenRoles.isEmpty ? const <String>['user'] : tokenRoles;
    final normalizedPrimaryRole = tokenPrimaryRole ?? normalizedRoles.first;
    debugPrint(
      '[AdminResolver] sync: token claims indicate admin for uid=${user.uid}; '
      'client profile write skipped (server-side trigger onUserRolesChanged '
      'owns the mirror).',
    );
    return _step(
      (state ?? AdminAccessState.initial()).copyWith(
        profileLoaded: state?.profileLoaded ?? false,
        profileHasAdmin: true,
        profileRoles: normalizedRoles,
        profilePrimaryRole: normalizedPrimaryRole,
      ),
      '[AdminResolver] in-memory profile flag set from token claims roles=$normalizedRoles',
      stage: 'profile-synced-from-token',
    );
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

    User callableUser;
    try {
      callableUser = await _ensureCurrentUserBound(user);
    } catch (error) {
      _diag('call skipped auth binding failed uid=${user.uid} error=$error');
      return _step(
        state.copyWith(
          serverCheckAttempted: true,
          serverCheckSucceeded: false,
          clearServerIsAdmin: true,
          serverErrorCode: 'unauthenticated',
          serverErrorMessage:
              'Session client non synchronisée avant l\'appel callable admin.',
        ),
        '[AdminResolver] server verification skipped auth binding failed',
        stage: 'server-access-error',
      );
    }

    _diag(
      'call start function=$_adminAccessCallableName type=callable '
      'region=$kFirebaseFunctionsRegion uid=${callableUser.uid}',
    );

    Future<AdminAccessState> runAttempt(bool retrying) async {
      try {
        try {
          final preflightToken = await callableUser.getIdToken(true);
          _diag(
            'call preflight getIdToken(true)=ok retry=$retrying '
            'len=${(preflightToken ?? '').length} '
            'preview=${_tokenPreview(preflightToken)}',
          );
        } catch (tokenError) {
          _diag(
            'call preflight getIdToken(true)=error retry=$retrying '
            'error=$tokenError',
          );
        }

        final response = await callPrestoFunction<dynamic>(
          functions: _functions,
          name: _adminAccessCallableName,
          timeout: _serverTimeout,
          parameters: const <String, dynamic>{},
        );
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        final isAdmin = data['isAdmin'] == true;
        final serverSource = _normalizedText(data['source']);
        final checkedAt = _dateTimeFromMilliseconds(data['checkedAt']);
        final debugData = data['debug'] is Map
            ? Map<String, dynamic>.from(data['debug'] as Map)
            : const <String, dynamic>{};

        _diag(
          'call success function=$_adminAccessCallableName '
          'code=ok body=$data',
        );

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
            adminDocLoaded: debugData.containsKey('adminDocExists'),
            adminDocHasAdmin: debugData['adminDocEnabled'] == true,
          ),
          '[AdminResolver] server verification success isAdmin=$isAdmin source=${serverSource ?? ''}',
          stage: 'server-access-ok',
        );
      } on FirebaseFunctionsException catch (error) {
        if (!retrying && error.code == 'unauthenticated') {
          debugPrint(
            '[AdminResolver] server verification failed unauthenticated',
          );
          debugPrint(
            '[AdminResolver] retrying via direct HTTP with explicit token',
          );
          _diag(
            'call error function=$_adminAccessCallableName '
            'code=${error.code} message=${error.message ?? ''} '
            'details=${error.details}',
          );
          // Fallback: appel HTTP direct avec le token rafraîchi explicitement
          // dans Authorization header, contourne les problèmes de SDK callable v2
          // sur Flutter Web où req.auth peut être absent malgré un token valide.
          try {
            final freshToken = await callableUser.getIdToken(true);
            _diag(
              'call http-fallback tokenRefresh=ok len=${(freshToken ?? '').length} '
              'preview=${_tokenPreview(freshToken)}',
            );
            if (freshToken != null && freshToken.isNotEmpty) {
              return _step(
                await _verifyServerAccessHttpFallback(
                  freshToken,
                  callableUser,
                  state,
                ),
                '[AdminResolver] http-fallback completed after unauthenticated',
              );
            }
          } catch (tokenError) {
            _diag('call http-fallback tokenRefresh=error error=$tokenError');
          }
        }

        _diag(
          'call error function=$_adminAccessCallableName '
          'code=${error.code} message=${error.message ?? ''} '
          'details=${error.details}',
        );

        return _step(
          state.copyWith(
            serverCheckAttempted: true,
            serverCheckSucceeded: false,
            clearServerIsAdmin: true,
            serverErrorCode: error.code,
            serverErrorMessage: _describeServerAccessError(
              error.code,
              fallback: error.message,
              state: state,
            ),
          ),
          '[AdminResolver] server verification failed ${error.code}',
          stage: 'server-access-error',
        );
      } catch (error) {
        _diag(
          'call error function=$_adminAccessCallableName '
          'code=unknown message=$error',
        );
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

  /// Appel HTTP direct à getMyAdminAccessStatus avec le token explicitement
  /// dans l'en-tête Authorization — contourne les problèmes du SDK callable
  /// v2 sur Flutter Web où req.auth peut être absent malgré un token valide.
  Future<AdminAccessState> _verifyServerAccessHttpFallback(
    String idToken,
    User user,
    AdminAccessState state,
  ) async {
    const projectId = 'presto-app-74abe';
    final url = Uri.parse(
      'https://$kFirebaseFunctionsRegion-$projectId.cloudfunctions.net/$_adminAccessCallableName',
    );
    _diag('call http-fallback start url=$url uid=${user.uid}');
    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'data': {}}),
          )
          .timeout(_serverTimeout);

      _diag(
        'call http-fallback response status=${response.statusCode} '
        'len=${response.body.length}',
      );

      Map<String, dynamic> body;
      try {
        final decoded = jsonDecode(response.body);
        body = decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
      } catch (_) {
        body = <String, dynamic>{};
      }

      if (response.statusCode == 200) {
        // Corps Firebase callable v2 : { result: { isAdmin, source, ... } }
        // ou { data: { isAdmin, ... } } selon endpoint
        final result = body['result'] is Map
            ? Map<String, dynamic>.from(body['result'] as Map)
            : body;

        final isAdmin = result['isAdmin'] == true;
        final serverSource = _normalizedText(result['source']);
        final checkedAt = _dateTimeFromMilliseconds(result['checkedAt']);
        final debugData = result['debug'] is Map
            ? Map<String, dynamic>.from(result['debug'] as Map)
            : const <String, dynamic>{};

        _diag(
          'call http-fallback success isAdmin=$isAdmin source=$serverSource',
        );
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
            adminDocLoaded: debugData.containsKey('adminDocExists'),
            adminDocHasAdmin: debugData['adminDocEnabled'] == true,
          ),
          '[AdminResolver] http-fallback success isAdmin=$isAdmin source=${serverSource ?? ''}',
          stage: 'server-access-ok',
        );
      }

      // Erreur JSON Firebase standard : { error: { status, message } }
      final errBody = body['error'] is Map
          ? Map<String, dynamic>.from(body['error'] as Map)
          : <String, dynamic>{};
      final errCode = _normalizedText(errBody['status'])?.toLowerCase() ??
          'http-${response.statusCode}';
      final errMsg =
          _normalizedText(errBody['message']) ?? 'HTTP ${response.statusCode}';

      _diag('call http-fallback error code=$errCode message=$errMsg');
      return _step(
        state.copyWith(
          uid: user.uid,
          email: user.email,
          serverCheckAttempted: true,
          serverCheckSucceeded: false,
          clearServerIsAdmin: true,
          serverErrorCode: errCode,
          serverErrorMessage: _describeServerAccessError(
            errCode,
            fallback: errMsg,
            state: state,
          ),
        ),
        '[AdminResolver] http-fallback failed code=$errCode',
        stage: 'server-access-error',
      );
    } catch (error) {
      _diag('call http-fallback exception error=$error');
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
        '[AdminResolver] http-fallback exception error=$error',
        stage: 'server-access-error',
      );
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getDocumentWithFallback(
    String collection,
    String docId,
  ) async {
    final reference = _firestore.collection(collection).doc(docId);
    final path = '$collection/$docId';
    try {
      _diag('firestore read start path=$path source=server');
      final serverSnapshot = await reference
          .get(const GetOptions(source: Source.server))
          .timeout(_documentServerTimeout);
      _diag(
        'firestore read success path=$path source=server exists=${serverSnapshot.exists}',
      );
      return serverSnapshot;
    } catch (error) {
      debugPrint(
        '[AdminResolver] $collection/$docId server read fallback: $error',
      );
      _diag('firestore read failed path=$path source=server error=$error');
      try {
        _diag('firestore read start path=$path source=cache');
        final cacheSnapshot = await reference
            .get(const GetOptions(source: Source.cache))
            .timeout(_documentCacheTimeout);
        _diag(
          'firestore read success path=$path source=cache exists=${cacheSnapshot.exists}',
        );
        return cacheSnapshot;
      } catch (cacheError) {
        debugPrint(
          '[AdminResolver] $collection/$docId cache read failed: $cacheError',
        );
        _diag(
          'firestore read failed path=$path source=cache error=$cacheError',
        );
        return null;
      }
    }
  }

  AdminAccessState _finalize(AdminAccessState state) {
    final sourceOfTruth = state.consolidatedSourceOfTruth;
    final effectiveIsAdmin = sourceOfTruth != 'none';
    final reason = switch (sourceOfTruth) {
      'server' => 'server-confirmed-admin',
      'token' => state.serverCheckSucceeded && state.serverIsAdmin == false
          ? 'token-fallback-after-server-denied'
          : 'token-claims-confirmed-admin',
      'profile' => state.serverCheckSucceeded && state.serverIsAdmin == false
          ? 'profile-fallback-after-server-denied'
          : 'profile-confirmed-admin',
      'adminDoc' => state.serverCheckSucceeded && state.serverIsAdmin == false
          ? 'admin-doc-fallback-after-server-denied'
          : 'admin-doc-confirmed-admin',
      _ => state.serverCheckSucceeded
          ? 'no-admin-source-after-server-check'
          : 'no-admin-source',
    };

    final finalized = _step(
      state.copyWith(
        effectiveIsAdmin: effectiveIsAdmin,
        sourceOfTruth: sourceOfTruth,
      ),
      '[AdminResolver] effectiveIsAdmin=$effectiveIsAdmin source=$sourceOfTruth reason=$reason',
      stage: 'finished',
    );
    debugPrint(
      '[AdminResolver][FinalAccess] profileSyncExpired=false '
      'serverIsAdmin=${state.serverIsAdmin} '
      'tokenHasAdmin=${state.tokenHasAdmin} '
      'profileHasAdmin=${state.profileHasAdmin} '
      'adminDocHasAdmin=${state.adminDocHasAdmin} '
      'finalCanAccessAdmin=$effectiveIsAdmin '
      'reason=$reason',
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

  Future<User> _ensureCurrentUserBound(User user) async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == user.uid) {
      return currentUser;
    }

    _diag(
      'auth rebind required current=${currentUser?.uid ?? 'null'} '
      'expected=${user.uid}',
    );

    try {
      final rebound = await _auth
          .userChanges()
          .firstWhere((candidate) => candidate?.uid == user.uid)
          .timeout(_authRebindTimeout, onTimeout: () => null);
      if (rebound != null) {
        _diag('auth rebind success uid=${rebound.uid}');
        return rebound;
      }
    } catch (error) {
      _diag('auth rebind stream failed error=$error');
    }

    final fallbackUser = _auth.currentUser;
    if (fallbackUser != null && fallbackUser.uid == user.uid) {
      _diag('auth rebind fallback success uid=${fallbackUser.uid}');
      return fallbackUser;
    }

    throw StateError('current user mismatch for uid=${user.uid}');
  }

  void _diag(String message) {
    debugPrint('[AdminResolver][Diag] $message');
  }

  String? _describeServerAccessError(
    String? code, {
    String? fallback,
    required AdminAccessState state,
  }) {
    if (code == 'unauthenticated' && state.tokenHasAdmin) {
      return 'La callable admin getMyAdminAccessStatus refuse l\'authentification alors que le token contient admin. Vérifie le déploiement Functions et la région $kFirebaseFunctionsRegion.';
    }
    return fallback;
  }

  String _firebaseProjectId() {
    try {
      return Firebase.app().options.projectId;
    } catch (_) {
      return 'unknown';
    }
  }

  String _tokenPreview(String? token) {
    final value = (token ?? '').trim();
    if (value.isEmpty) {
      return '-';
    }
    if (value.length <= 20) {
      return value;
    }
    return '${value.substring(0, 10)}...${value.substring(value.length - 10)}';
  }

  List<String> _rolesFromValue(dynamic value) =>
      _accessPolicy.normalizeRoles(value);

  bool _hasAdminAccess(
    Map<String, dynamic>? data, {
    required List<String> roles,
    required String? primaryRole,
  }) =>
      _accessPolicy.hasAdminAccess(
        data,
        roles: roles,
        primaryRole: primaryRole,
      );

  String? _firstNormalizedText(Map<String, dynamic>? data, List<String> keys) =>
      _accessPolicy.firstNormalizedText(data, keys);

  String? _normalizedText(dynamic value) => _accessPolicy.normalizeText(value);

  DateTime? _dateTimeFromMilliseconds(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}
