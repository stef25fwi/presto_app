import 'package:firebase_auth/firebase_auth.dart';

/// Résultat de `FirebaseAuth.getRedirectResult()` capturé une seule fois au
/// démarrage web pour éviter une course entre le bootstrap et les pages compte.
UserCredential? pendingRedirectAuthResult;
Object? pendingRedirectAuthError;
String? pendingPostAuthRoute;
