import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DebugAuth {
  static StreamSubscription<User?>? _authStateSub;
  static StreamSubscription<User?>? _idTokenSub;

  static void installAuthStateLogs() {
    // Cancel before re-installing — avoids listener accumulation on hot reload.
    _authStateSub?.cancel();
    _idTokenSub?.cancel();

    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint(
        '[AUTH] authStateChanges: authenticated=${user != null}',
      );
    }, onError: (e) {
      debugPrint('[AUTH] authStateChanges ERROR: $e');
    });

    _idTokenSub = FirebaseAuth.instance.idTokenChanges().listen((user) async {
      final token = user == null ? null : await user.getIdToken();
      final tokenLabel = token == null
          ? 'null'
          : (token.length <= 12 ? '$token...' : '${token.substring(0, 12)}...');
      debugPrint(
        '[AUTH] idTokenChanges: user=${user?.uid} token=$tokenLabel',
      );
    }, onError: (e) {
      debugPrint('[AUTH] idTokenChanges ERROR: $e');
    });
  }

  static Future<void> debugRedirectResultAtStartup() async {
    if (!kIsWeb) return;
    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      debugPrint(
        '[AUTH] getRedirectResult: user=${result.user?.uid} cred=${result.credential?.providerId}',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AUTH] getRedirectResult FirebaseAuthException: ${e.code} ${e.message}',
      );
    } catch (e) {
      debugPrint('[AUTH] getRedirectResult ERROR: $e');
    }
  }

  static Future<void> signInGoogleDebug() async {
    final auth = FirebaseAuth.instance;
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});

    try {
      if (kIsWeb) {
        await auth.setPersistence(Persistence.LOCAL);
        debugPrint('[AUTH] signInWithRedirect() start');
        await auth.signInWithRedirect(provider);
        // Après ça, le navigateur redirige (normal)
      } else {
        debugPrint('[AUTH] signInWithProvider() start');
        final cred = await auth.signInWithProvider(provider);
        debugPrint('[AUTH] signInWithProvider() success uid=${cred.user?.uid}');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] signIn FirebaseAuthException: ${e.code} ${e.message}');
      // Codes utiles:
      // unauthorized-domain, operation-not-allowed, popup-blocked, popup-closed-by-user
    } catch (e) {
      debugPrint('[AUTH] signIn ERROR: $e');
    }
  }
}
