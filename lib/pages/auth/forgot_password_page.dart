import 'package:flutter/material.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/auth_service.dart';
import 'reset_password_success_page.dart';

typedef ForgotPasswordResetSender = Future<void> Function({
  required String email,
});
typedef ForgotPasswordErrorMessageMapper = String Function(Object error);
typedef ForgotPasswordSuccessPageBuilder = Widget Function(String email);

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.sendPasswordReset,
    this.errorMessageMapper,
    this.successPageBuilder,
  });

  static const routeName = '/forgot-password';

  final ForgotPasswordResetSender? sendPasswordReset;
  final ForgotPasswordErrorMessageMapper? errorMessageMapper;
  final ForgotPasswordSuccessPageBuilder? successPageBuilder;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final sendPasswordReset = widget.sendPasswordReset ??
          ({required String email}) =>
              AuthService.instance.sendPasswordReset(email: email);
      await sendPasswordReset(email: email);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.successPageBuilder?.call(email) ??
              ResetPasswordSuccessPage(email: email),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final messageMapper = widget.errorMessageMapper ?? AuthErrorMapper.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageMapper(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Adresse e-mail obligatoire.';
    if (!text.contains('@')) return 'Adresse e-mail invalide.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1A73E8);

    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(Icons.lock_reset, size: 72, color: blue),
                    const SizedBox(height: 16),
                    const Text(
                      'Réinitialiser votre mot de passe',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Indiquez votre adresse e-mail. Si un compte iliprestō existe avec cette adresse, vous recevrez un lien sécurisé pour choisir un nouveau mot de passe.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adresse e-mail',
                        border: OutlineInputBorder(),
                      ),
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _sendReset,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Envoyer le lien'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
