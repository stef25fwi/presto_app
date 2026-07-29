import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/phone_verification_service.dart';

/// Vérifie le numéro de téléphone de l'utilisateur par SMS (Firebase Phone
/// Auth). Retourne `true` via [Navigator.pop] si la vérification a réussi.
class PhoneVerificationPage extends StatefulWidget {
  const PhoneVerificationPage({
    super.key,
    this.phoneVerificationService,
    this.initialPhoneNumber,
  });

  static const routeName = '/account/verify-phone';

  @visibleForTesting
  final PhoneVerificationService? phoneVerificationService;

  /// Numéro pré-rempli. Si `null`, repris de l'utilisateur connecté.
  @visibleForTesting
  final String? initialPhoneNumber;

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

enum _PhoneVerificationStep { enterPhone, enterCode }

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  static final RegExp _e164Pattern = RegExp(r'^\+[0-9]{10,15}$');

  late final PhoneVerificationService _service =
      widget.phoneVerificationService ?? PhoneVerificationService();
  final _phoneFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  late final _phoneController = TextEditingController(
    text: widget.initialPhoneNumber ??
        FirebaseAuth.instance.currentUser?.phoneNumber ??
        '',
  );
  final _codeController = TextEditingController();

  _PhoneVerificationStep _step = _PhoneVerificationStep.enterPhone;
  String? _verificationId;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    await _service.sendCode(
      phoneNumber: _phoneController.text.trim(),
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _step = _PhoneVerificationStep.enterCode;
          _loading = false;
        });
      },
      onFailed: (error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = AuthErrorMapper.message(error);
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
        _errorMessage = AuthErrorMapper.message(error);
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
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: 'Ex : +33612345678',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) return 'Numéro obligatoire.';
              if (!_e164Pattern.hasMatch(trimmed)) {
                return 'Format attendu : +indicatif suivi du numéro (ex : +33612345678).';
              }
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
            'Un code a été envoyé au ${_phoneController.text.trim()}. Saisis-le ci-dessous.',
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
            child: const Text('Changer de numéro / renvoyer un code'),
          ),
        ],
      ),
    );
  }
}
