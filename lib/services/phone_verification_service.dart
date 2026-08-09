import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_functions_region.dart';

typedef PhoneVerifyStarter = Future<void> Function({
  required String phoneNumber,
  required Duration timeout,
  required void Function(PhoneAuthCredential credential) verificationCompleted,
  required void Function(FirebaseAuthException error) verificationFailed,
  required void Function(String verificationId, int? resendToken) codeSent,
  required void Function(String verificationId) codeAutoRetrievalTimeout,
});
typedef PhoneCredentialLinker = Future<void> Function(
  PhoneAuthCredential credential,
);
typedef PhoneConfirmCaller = Future<Object?> Function();
typedef PhoneAttemptReserver = Future<Object?> Function(String phoneNumber);

/// Vérification du numéro de téléphone par SMS via Firebase Phone Auth.
///
/// Firebase Auth n'a pas de notion de « numéro lié mais non vérifié » :
/// `user.phoneNumber` n'est renseigné qu'après confirmation réussie du code
/// SMS. La confirmation côté serveur (`confirmPhoneVerified`) relit ce champ
/// via l'Admin SDK pour renseigner `phoneVerified` dans Firestore de façon
/// fiable, sans faire confiance à une déclaration du client.
class PhoneVerificationService {
  PhoneVerificationService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    PhoneVerifyStarter? verifyStarter,
    PhoneCredentialLinker? linker,
    PhoneConfirmCaller? confirmCaller,
    PhoneAttemptReserver? attemptReserver,
  })  : _authOverride = auth,
        _functionsOverride = functions,
        _verifyStarter = verifyStarter,
        _linker = linker,
        _confirmCaller = confirmCaller,
        _attemptReserver = attemptReserver;

  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;
  final PhoneVerifyStarter? _verifyStarter;
  final PhoneCredentialLinker? _linker;
  final PhoneConfirmCaller? _confirmCaller;
  final PhoneAttemptReserver? _attemptReserver;

  // Évalués paresseusement : ne touchent Firebase que si aucune dépendance
  // de test n'a été injectée (utile pour les tests unitaires sans app
  // Firebase initialisée).
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? prestoFirebaseFunctions;

  /// Réserve la tentative SMS côté serveur avant l'appel Firebase Phone Auth.
  /// Les comptes free sont limités à une tentative par fenêtre de 24 h ; les
  /// plans supérieurs et comptes privilégiés sont exemptés côté backend.
  Future<Map<String, dynamic>> reserveDailyAttempt({
    required String phoneNumber,
  }) async {
    final reserver = _attemptReserver;
    final rawData = reserver != null
        ? await reserver(phoneNumber)
        : (await callPrestoFunction<dynamic>(
            functions: _functions,
            name: 'reservePhoneVerificationAttempt',
            timeout: const Duration(seconds: 20),
            parameters: <String, dynamic>{'phoneNumber': phoneNumber},
          ))
            .data;
    final data = Map<String, dynamic>.from(
      (rawData as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
    if (data['allowed'] != true) {
      throw StateError('La tentative SMS n’a pas été autorisée.');
    }
    return data;
  }

  /// Déclenche l'envoi du SMS. `onAutoVerified` est appelé si la plateforme
  /// (Android, la plupart du temps) confirme automatiquement le code sans
  /// saisie utilisateur.
  Future<void> sendCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
    required Future<void> Function() onAutoVerified,
  }) async {
    final starter = _verifyStarter ?? _defaultVerifyStarter;
    await starter(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await _linkOrUpdate(credential);
          await onAutoVerified();
        } on FirebaseAuthException catch (error) {
          onFailed(error);
        }
      },
      verificationFailed: onFailed,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Confirme le code saisi par l'utilisateur, lie le numéro au compte, puis
  /// demande au serveur de marquer `phoneVerified` dans Firestore.
  /// Retourne `true` si la confirmation serveur a réussi.
  Future<bool> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _linkOrUpdate(credential);
    return confirmServerSide();
  }

  Future<void> _defaultVerifyStarter({
    required String phoneNumber,
    required Duration timeout,
    required void Function(PhoneAuthCredential credential)
        verificationCompleted,
    required void Function(FirebaseAuthException error) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> _linkOrUpdate(PhoneAuthCredential credential) async {
    final linker = _linker;
    if (linker != null) {
      await linker(credential);
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Aucun utilisateur connecté.');
    }
    if ((user.phoneNumber ?? '').trim().isNotEmpty) {
      await user.updatePhoneNumber(credential);
    } else {
      await user.linkWithCredential(credential);
    }
  }

  Future<bool> confirmServerSide() async {
    final caller = _confirmCaller;
    final rawData = caller != null
        ? await caller()
        : (await callPrestoFunction<dynamic>(
            functions: _functions,
            name: 'confirmPhoneVerified',
            timeout: const Duration(seconds: 20),
          ))
            .data;
    final data = Map<String, dynamic>.from(
      (rawData as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
    return data['ok'] == true;
  }
}
