import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/auth_service.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  static const routeName = '/verify-email';

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _loading = false;
  int _secondsBeforeResend = 30;
  Timer? _timer;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsBeforeResend = 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsBeforeResend <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsBeforeResend = 0);
      } else {
        if (mounted) setState(() => _secondsBeforeResend--);
      }
    });
  }

  Future<void> _checkVerified() async {
    setState(() => _loading = true);

    try {
      final verified = await AuthService.instance.checkEmailVerified();

      if (!mounted) return;

      if (verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email validé avec succès.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Email pas encore validé. Clique sur le lien reçu.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.message(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _loading = true);

    try {
      await AuthService.instance.resendVerificationEmail();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de confirmation renvoyé.')),
      );

      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.message(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);
    final email = _user?.email ?? 'ton adresse email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirme ton email'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _logout,
            child: const Text('Déconnexion'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user, size: 82, color: orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Validation obligatoire',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Un lien de validation a été envoyé à $email. Clique dessus pour activer toutes les fonctions Prestō.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _checkVerified,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text('J’ai validé mon email'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed:
                          _loading || _secondsBeforeResend > 0 ? null : _resend,
                      child: Text(
                        _secondsBeforeResend > 0
                            ? 'Renvoyer dans $_secondsBeforeResend s'
                            : 'Renvoyer l’email',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
