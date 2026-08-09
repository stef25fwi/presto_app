import 'dart:async';

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
typedef PhoneAttemptCommitter = Future<Object?> Function(String reservationId);
typedef PhoneAttemptReleaser = Future<Object?> Function(
  String reservationId,
  String reason,
);

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
    PhoneAttemptCommitter? attemptCommitter,
    PhoneAttemptReleaser? attemptReleaser,
    Duration smsCallbackWatchdogTimeout = const Duration(seconds: 90),
  })  : _authOverride = auth,
        _functionsOverride = functions,
        _verifyStarter = verifyStarter,
        _linker = linker,
        _confirmCaller = confirmCaller,
        _attemptReserver = attemptReserver,
        _attemptCommitter = attemptCommitter,
        _attemptReleaser = attemptReleaser,
        _smsCallbackWatchdogTimeout = smsCallbackWatchdogTimeout;

  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;
  final PhoneVerifyStarter? _verifyStarter;
  final PhoneCredentialLinker? _linker;
  final PhoneConfirmCaller? _confirmCaller;
  final PhoneAttemptReserver? _attemptReserver;
  final PhoneAttemptCommitter? _attemptCommitter;
  final PhoneAttemptReleaser? _attemptReleaser;
  final Duration _smsCallbackWatchdogTimeout;

  String? _pendingReservationId;
  bool _smsDispatchConfirmed = false;

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
            parameters: <String, dynamic>{
              'action': 'reserve',
              'phoneNumber': phoneNumber,
            },
          ))
            .data;
    final data = Map<String, dynamic>.from(
      (rawData as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
    if (data['allowed'] != true) {
      throw StateError('La tentative SMS n’a pas été autorisée.');
    }

    final reservationId = data['reservationId']?.toString().trim() ?? '';
    _pendingReservationId = reservationId.isEmpty ? null : reservationId;
    _smsDispatchConfirmed = false;
    return data;
  }

  Future<bool> commitDailyAttempt({required String reservationId}) async {
    final committer = _attemptCommitter;
    final rawData = committer != null
        ? await committer(reservationId)
        : (await callPrestoFunction<dynamic>(
            functions: _functions,
            name: 'reservePhoneVerificationAttempt',
            timeout: const Duration(seconds: 20),
            parameters: <String, dynamic>{
              'action': 'commit',
              'reservationId': reservationId,
            },
          ))
            .data;
    final data = Map<String, dynamic>.from(
      (rawData as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
    return data['committed'] == true;
  }

  Future<bool> releaseDailyAttempt({
    required String reservationId,
    required String reason,
  }) async {
    final releaser = _attemptReleaser;
    final rawData = releaser != null
        ? await releaser(reservationId, reason)
        : (await callPrestoFunction<dynamic>(
            functions: _functions,
            name: 'reservePhoneVerificationAttempt',
            timeout: const Duration(seconds: 20),
            parameters: <String, dynamic>{
              'action': 'release',
              'reservationId': reservationId,
              'reason': reason,
            },
          ))
            .data;
    final data = Map<String, dynamic>.from(
      (rawData as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
    return data['released'] == true;
  }

  Future<void> _commitPendingAttempt() async {
    final reservationId = _pendingReservationId;
    // Ces mutations locales sont synchrones et empêchent tout callback tardif
    // de libérer une tentative après que Firebase a confirmé l'envoi.
    _smsDispatchConfirmed = true;
    _pendingReservationId = null;
    if (reservationId == null || reservationId.isEmpty) return;

    // Même si le marquage `sent` échoue temporairement, la réservation initiale
    // continue de consommer le quota : on ne risque donc pas un double envoi.
    try {
      await commitDailyAttempt(reservationId: reservationId);
    } catch (_) {
      // Le quota reste conservateur côté serveur grâce à `lastAttemptAt`.
    }
  }

  Future<void> _releasePendingAttempt(String reason) async {
    final reservationId = _pendingReservationId;
    if (_smsDispatchConfirmed || reservationId == null || reservationId.isEmpty) {
      return;
    }

    try {
      final released = await releaseDailyAttempt(
        reservationId: reservationId,
        reason: reason,
      );
      if (released) {
        _pendingReservationId = null;
      }
    } catch (_) {
      // Conserver l'identifiant permet à un nouvel essai dans la même page de
      // tenter à nouveau le nettoyage avant d'écraser la réservation locale.
    }
  }

  /// Déclenche l'envoi du SMS. `onAutoVerified` est appelé si la plateforme
  /// (Android, la plupart du temps) confirme automatiquement le code sans
  /// saisie utilisateur.
  ///
  /// Une réservation free n'est définitivement consommée qu'à partir du
  /// callback Firebase `codeSent` (ou d'une vérification automatique). Si
  /// Firebase échoue avant ce callback, la réservation est libérée côté
  /// serveur avant de transmettre l'erreur à l'interface.
  ///
  /// Certains échecs d'attestation Android peuvent exceptionnellement ne faire
  /// remonter aucun callback Firebase. Un watchdog ferme alors le spinner et
  /// libère la réservation afin que l'utilisateur ne reste jamais bloqué.
  Future<void> sendCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
    required Future<void> Function() onAutoVerified,
  }) async {
    final starter = _verifyStarter ?? _defaultVerifyStarter;
    var codeSentObserved = false;
    var terminalCallbackDelivered = false;
    Timer? watchdog;

    Future<void> failBeforeCodeSent(
      FirebaseAuthException error,
      String releaseReason,
    ) async {
      if (terminalCallbackDelivered || codeSentObserved) return;
      terminalCallbackDelivered = true;
      watchdog?.cancel();
      await _releasePendingAttempt(releaseReason);
      onFailed(error);
    }

    void handleFailure(FirebaseAuthException error) {
      if (terminalCallbackDelivered || codeSentObserved) return;
      unawaited(
        failBeforeCodeSent(error, 'firebase_${error.code}'),
      );
    }

    void handleCodeSent(String verificationId) {
      if (terminalCallbackDelivered) return;
      terminalCallbackDelivered = true;
      codeSentObserved = true;
      watchdog?.cancel();
      unawaited(_commitPendingAttempt());
      onCodeSent(verificationId);
    }

    void handleAutoVerified(PhoneAuthCredential credential) {
      if (terminalCallbackDelivered) return;
      terminalCallbackDelivered = true;
      codeSentObserved = true;
      watchdog?.cancel();
      unawaited(_commitPendingAttempt());
      unawaited(() async {
        try {
          await _linkOrUpdate(credential);
          await onAutoVerified();
        } on FirebaseAuthException catch (error) {
          onFailed(error);
        }
      }());
    }

    void handleAutoRetrievalTimeout(String _) {
      if (terminalCallbackDelivered || codeSentObserved) return;
      unawaited(
        failBeforeCodeSent(
          FirebaseAuthException(
            code: 'phone-verification-timeout',
            message:
                'Firebase Phone Auth n’a pas confirmé le démarrage de l’envoi SMS.',
          ),
          'firebase_auto_retrieval_timeout',
        ),
      );
    }

    watchdog = Timer(_smsCallbackWatchdogTimeout, () {
      if (terminalCallbackDelivered || codeSentObserved) return;
      unawaited(
        failBeforeCodeSent(
          FirebaseAuthException(
            code: 'phone-verification-timeout',
            message:
                'Firebase Phone Auth n’a renvoyé aucun callback dans le délai attendu.',
          ),
          'firebase_callback_timeout',
        ),
      );
    });

    try {
      await starter(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: handleAutoVerified,
        verificationFailed: handleFailure,
        codeSent: (verificationId, _) => handleCodeSent(verificationId),
        codeAutoRetrievalTimeout: handleAutoRetrievalTimeout,
      );
    } on FirebaseAuthException catch (error) {
      await failBeforeCodeSent(error, 'firebase_${error.code}');
    } catch (_) {
      await failBeforeCodeSent(
        FirebaseAuthException(
          code: 'phone-verification-start-failed',
          message: 'Impossible de démarrer Firebase Phone Auth.',
        ),
        'firebase_start_failed',
      );
    }
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
