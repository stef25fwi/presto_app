import 'package:flutter/material.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/auth_service.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AuthService.instance.signInWithEmail(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(AuthErrorMapper.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      _showError(AuthErrorMapper.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apple() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithApple();
    } catch (e) {
      if (!mounted) return;
      _showError(AuthErrorMapper.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email obligatoire.';
    if (!text.contains('@')) return 'Email invalide.';
    return null;
  }

  String? _passwordValidator(String? value) {
    if ((value ?? '').isEmpty) return 'Mot de passe obligatoire.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);
    const blue = Color(0xFF1A73E8);

    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
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
                      'Connecte-toi à Prestō',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 24),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                ),
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(backgroundColor: orange),
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Se connecter'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _google,
                        icon: const Icon(Icons.g_mobiledata),
                        label: const Text('Continuer avec Google'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _apple,
                        icon: const Icon(Icons.apple),
                        label: const Text('Continuer avec Apple'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              ),
                      child: const Text(
                        'Créer un compte',
                        style: TextStyle(color: blue),
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
