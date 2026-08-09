import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/geo_api_gouv_service.dart';
import '../../services/phone_verification_service.dart';
import '../../utils/phone_number_utils.dart';
import '../../widgets/phone_input_field.dart';

/// Vérifie le numéro de téléphone de l'utilisateur par SMS (Firebase Phone
/// Auth). Retourne `true` via [Navigator.pop] si la vérification a réussi.
class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({
    super.key,
    this.phoneVerificationService,
    this.geoApiGouvService,
    this.initialPhoneNumber,
  });

  static const routeName = '/account/verify-phone';

  @visibleForTesting
  final PhoneVerificationService? phoneVerificationService;

  @visibleForTesting
  final GeoApiGouvService? geoApiGouvService;

  /// Numéro pré-rempli. Si `null`, repris du profil/utilisateur connecté.
  /// Une chaîne vide explicite désactive l'hydratation Firestore dans les tests.
  @visibleForTesting
  final String? initialPhoneNumber;

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

enum _PhoneVerificationStep { enterPhone, enterCode }

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  late final PhoneVerificationService _service =
      widget.phoneVerificationService ?? PhoneVerificationService();
  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  final _codeController = TextEditingController();

  _PhoneVerificationStep _step = _PhoneVerificationStep.enterPhone;
  String _phoneCountryCode = '+33';
  String _normalizedPhoneNumber = '';
  String? _verificationId;
  bool _loading = false;
  bool _hydratingPhone = false;
  String? _errorMessage;
  Timer? _hydrationTimeoutTimer;
  void Function()? _cancelHydrationWait;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();

    final explicitInitial = widget.initialPhoneNumber;
    final initialPhone = explicitInitial ??
        FirebaseAuth.instance.currentUser?.phoneNumber ??
        '';
    _applyPhoneValue(initialPhone);

    if (explicitInitial == null && initialPhone.trim().isEmpty) {
      unawaited(_hydratePhoneDefaults());
    }
  }

  @override
  void dispose() {
    _cancelHydrationWait?.call();
    _cancelHydrationWait = null;
    _hydrationTimeoutTimer?.cancel();
    _hydrationTimeoutTimer = null;
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _applyPhoneValue(String rawPhone) {
    final trimmed = rawPhone.trim();
    final detectedCode = phoneCountryCodeFromE164(trimmed);
    if (detectedCode != null) {
      _phoneCountryCode = detectedCode;
      _phoneController.text = phoneLocalNumberFromE164(trimmed);
      return;
    }
    _phoneController.text = trimmed;
  }

  String _firstProfileValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<T> _withHydrationTimeout<T>(Future<T> future) async {
    final completer = Completer<T>();
    late final Timer timer;

    void completeValue(T value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    void completeError(Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }

    timer = Timer(const Duration(seconds: 8), () {
      completeError(
        TimeoutException('Hydratation du profil téléphone expirée.'),
        StackTrace.current,
      );
    });
    _hydrationTimeoutTimer = timer;
    _cancelHydrationWait = () {
      timer.cancel();
      completeError(
        StateError('Hydratation du profil téléphone annulée.'),
        StackTrace.current,
      );
    };

    future.then(completeValue, onError: completeError);

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      if (identical(_hydrationTimeoutTimer, timer)) {
        _hydrationTimeoutTimer = null;
      }
      _cancelHydrationWait = null;
    }
  }

  Future<void> _hydratePhoneDefaults() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _hydratingPhone = true);
    try {
      final snapshot = await _withHydrationTimeout(
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      );
      if (!mounted) return;
      final data = snapshot.data() ?? const <String, dynamic>{};

      final storedPhone = _firstProfileValue(
        data,
        const ['phone', 'telephone', 'phoneNumber', 'phone_number'],
      );
      if (storedPhone.isNotEmpty) {
        if (!mounted) return;
        setState(() => _applyPhoneValue(storedPhone));
        return;
      }

      final storedCountryCode =
          _firstProfileValue(data, const ['phoneCountryCode']);
      final postalCode = _firstProfileValue(
        data,
        const ['postalCode', 'codePostal', 'zipCode', 'cp'],
      );
      final city = _firstProfileValue(
        data,
        const ['city', 'ville', 'commune', 'locality'],
      );

      String? departmentCode;
      final geoService = widget.geoApiGouvService ?? GeoApiGouvService();
      final ownsGeoService = widget.geoApiGouvService == null;
      try {
        if (RegExp(r'^\d{5}$').hasMatch(postalCode)) {
          final matches = await geoService.findCommunesByPostalCode(
            postalCode,
            limit: 3,
          );
          if (matches.isNotEmpty) {
            departmentCode = matches.first.departmentCode;
          }
        } else if (city.length >= 2) {
          final matches = await geoService.searchCommunesByName(
            city,
            limit: 3,
          );
          if (matches.isNotEmpty) {
            departmentCode = matches.first.departmentCode;
          }
        }
      } finally {
        if (ownsGeoService) geoService.close();
      }

      final geoCountryCode = departmentCode == null || departmentCode.isEmpty
          ? null
          : phoneCountryCodeForDepartment(departmentCode);
      final fallbackCountryCode =
          kSupportedPhoneCountryCodes.contains(storedCountryCode)
              ? storedCountryCode
              : '+33';
      final nextCountryCode = geoCountryCode ?? fallbackCountryCode;

      if (!mounted) return;
      setState(() => _phoneCountryCode = nextCountryCode);
    } catch (_) {
      // La détection Geo API Gouv améliore l'UX mais ne doit jamais empêcher
      // une vérification manuelle : le sélecteur reste disponible en fallback.
    } finally {
      if (mounted) setState(() => _hydratingPhone = false);
    }
  }

  String _normalizedCurrentPhone() {
    return normalizePhoneNumberE164(
      countryCode: _phoneCountryCode,
      rawPhone: _phoneController.text,
    );
  }

  String _quotaErrorMessage(FirebaseFunctionsException error) {
    if (error.code != 'resource-exhausted') {
      final message = error.message?.trim() ?? '';
      return message.isNotEmpty
          ? message
          : 'La vérification du quota SMS a échoué. Réessaie.';
    }

    String? nextAllowedAt;
    final details = error.details;
    if (details is Map) {
      nextAllowedAt = details['nextAllowedAt']?.toString();
    }
    final parsed = DateTime.tryParse(nextAllowedAt ?? '')?.toLocal();
    if (parsed == null) {
      return 'Quota atteint : l’offre gratuite autorise 1 tentative SMS toutes les 24 h.';
    }

    String two(int value) => value.toString().padLeft(2, '0');
    final formatted =
        '${two(parsed.day)}/${two(parsed.month)} à ${two(parsed.hour)}:${two(parsed.minute)}';
    return 'Quota atteint : l’offre gratuite autorise 1 tentative SMS toutes les 24 h. Nouvelle tentative possible le $formatted.';
  }

  Future<void> _sendCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final normalizedPhone = _normalizedCurrentPhone();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _service.reserveDailyAttempt(phoneNumber: normalizedPhone);
      await _service.sendCode(
        phoneNumber: normalizedPhone,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _normalizedPhoneNumber = normalizedPhone;
            _verificationId = verificationId;
            _step = _PhoneVerificationStep.enterCode;
            _loading = false;
          });
        },
        onFailed: (error) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _errorMessage =
                '${AuthErrorMapper.message(error)} La tentative SMS du jour a été comptabilisée.';
          });
        },
        onAutoVerified: () async {
          final confirmed = await _service.confirmServerSide();
          if (!mounted) return;
          setState(() => _loading = false);
          if (confirmed) {
            Navigator.of(context).pop(true);
          } else {
            setState(() {
              _errorMessage =
                  'La vérification a échoué côté serveur. Réessaie.';
            });
          }
        },
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _quotaErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Impossible de démarrer la vérification SMS. Réessaie.';
      });
    }
  }

  Future<void> _confirmCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    final verificationId = _verificationId;
    if (verificationId == null) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final confirmed = await _service.confirmCode(
        verificationId: verificationId,
        smsCode: _codeController.text.trim(),
      );
      if (!mounted) return;
      if (confirmed) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _loading = false;
          _errorMessage = 'La vérification a échoué côté serveur. Réessaie.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error is FirebaseAuthException
            ? AuthErrorMapper.message(error)
            : 'Le code n’a pas pu être vérifié. Réessaie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6600),
        foregroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: const Color(0xFFFF6600),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Vérifier mon téléphone'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _step == _PhoneVerificationStep.enterPhone
            ? _buildPhoneStep()
            : _buildCodeStep(),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: ListView(
        children: [
          const Text(
            'Reçois un code par SMS pour confirmer ton numéro de téléphone.',
            style: TextStyle(height: 1.35),
          ),
          const SizedBox(height: 8),
          const Text(
            'Offre gratuite : 1 tentative d’envoi SMS toutes les 24 h.',
            style: TextStyle(
              height: 1.35,
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          PhoneInputFieldCompact(
            controller: _phoneController,
            labelText: 'Numéro de téléphone',
            hintText: phoneHintForCountryCode(_phoneCountryCode),
            initialCountryCode: _phoneCountryCode,
            onCountryCodeChanged: (code) {
              if (!mounted || code == _phoneCountryCode) return;
              setState(() => _phoneCountryCode = code);
            },
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) return 'Numéro obligatoire.';
              final normalized = normalizePhoneNumberE164(
                countryCode: _phoneCountryCode,
                rawPhone: trimmed,
              );
              if (!isValidE164PhoneNumber(normalized)) {
                return 'Numéro invalide. Vérifie l’indicatif et le numéro.';
              }
              return null;
            },
          ),
          if (_hydratingPhone) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Détection de l’indicatif depuis ton profil…',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, height: 1.3),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendCode,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Envoyer le code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      child: ListView(
        children: [
          Text(
            'Un code a été envoyé au $_normalizedPhoneNumber. Saisis-le ci-dessous.',
            style: const TextStyle(height: 1.35),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'Code reçu par SMS',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) return 'Code obligatoire.';
              if (trimmed.length < 4) return 'Code incomplet.';
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, height: 1.3),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _confirmCode,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Vérifier'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _step = _PhoneVerificationStep.enterPhone;
                      _verificationId = null;
                      _codeController.clear();
                      _errorMessage = null;
                    });
                  },
            child: const Text('Changer de numéro'),
          ),
        ],
      ),
    );
  }
}
