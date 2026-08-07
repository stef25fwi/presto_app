import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app/runtime_stores.dart';
import '../app/startup_state.dart';
import '../app_core.dart';
import '../debug_auth.dart';
import '../services/post_auth_navigation_intent_service.dart';

Future<void> initializeAuthState() async {
  try {
    final auth = FirebaseAuth.instance;
    if (kDebugMode) DebugAuth.installAuthStateLogs();

    if (kIsWeb) {
      try {
        await auth.setPersistence(Persistence.LOCAL);
      } catch (error) {
        if (kDebugMode) debugPrint('[Auth] setPersistence failed: $error');
      }

      try {
        pendingRedirectAuthResult = await auth
            .getRedirectResult()
            .timeout(const Duration(seconds: 10));
        if (kDebugMode) {
          debugPrint(
            '[Auth] getRedirectResult: user='
            '${pendingRedirectAuthResult?.user?.uid} '
            'provider=${pendingRedirectAuthResult?.credential?.providerId}',
          );
        }
      } catch (error) {
        pendingRedirectAuthError = error;
        if (kDebugMode) debugPrint('[Auth] getRedirectResult error: $error');
      }

      final shouldRestorePostAuthRoute =
          pendingRedirectAuthResult?.user != null || pendingRedirectAuthError != null;
      if (shouldRestorePostAuthRoute) {
        try {
          pendingPostAuthRoute =
              await PostAuthNavigationIntentService.takePendingRoute();
          if (kDebugMode && pendingPostAuthRoute != null) {
            debugPrint('[Auth] pending post-auth route=$pendingPostAuthRoute');
          }
        } catch (error) {
          if (kDebugMode) debugPrint('[Auth] takePendingRoute failed: $error');
        }
      }
    }

    if (auth.currentUser != null) {
      if (kDebugMode) {
        debugPrint('[Auth] User already signed in: ${auth.currentUser!.uid}');
      }
      SessionState.userId = auth.currentUser!.uid;
    } else {
      if (kDebugMode) debugPrint('[Auth] No user signed in at startup (OK)');
      SessionState.userId = null;
    }

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      SessionState.userId = user?.uid;
      adminWebDebugStore.updateAuth(user);
      if (kDebugMode) {
        debugPrint('[Auth] global state changed: ${user?.uid ?? "null"}');
      }
    });
  } catch (error) {
    adminWebDebugStore.recordError(
      'auth',
      error,
      message: 'startup-check-failed',
    );
    if (kDebugMode) debugPrint('[Auth] check failed: $error');
  }
}
