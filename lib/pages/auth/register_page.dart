import 'package:flutter/material.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/auth_service.dart';
import 'verify_email_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  static const routeName = '/register';

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AuthService.instance.registerWithEmail(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const VerifyEmailPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.message(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _nameValidator(String? value) {
    if ((value ?? '').trim().length < 2) return 'Nom obligatoire.';
    return null;
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email obligatoire.';
    if (!text.contains('@')) return 'Email invalide.';
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.length < 8) return '8 caractères minimum.';
    if (!RegExp(r'[A-Za-z]').hasMatch(text))
      return 'Ajoute au moins une lettre.';
    if (!RegExp(r'[0-9]').hasMatch(text)) return 'Ajoute au moins un chiffre.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
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
                    const Text(
                      'Bienvenue sur Prestō',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom affiché',
                        border: OutlineInputBorder(),
                      ),
                      validator: _nameValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(backgroundColor: orange),
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Créer mon compte'),
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
