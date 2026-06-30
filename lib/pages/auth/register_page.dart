import 'package:flutter/material.dart';

import '../../pages/legal_info_page.dart';
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
  final _fullNameCtrl = TextEditingController();
  final _pseudoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _pseudoCtrl.dispose();
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
        displayName: _pseudoCtrl.text.trim(),
        fullName: _fullNameCtrl.text.trim(),
        pseudo: _pseudoCtrl.text.trim(),
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

  String? _fullNameValidator(String? value) {
    if ((value ?? '').trim().length < 2) return 'Nom et prénom obligatoires.';
    return null;
  }

  String? _pseudoValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 2) return 'Pseudo obligatoire (2 caractères minimum).';
    if (text.length > 30) return 'Pseudo trop long (30 caractères maximum).';
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
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) {
      return 'Ajoute au moins une lettre.';
    }
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Bienvenue sur Prestō',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Particulier',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _fullNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom + Prénom',
                        hintText: 'Ex : Martin Dupont',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _fullNameValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pseudoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pseudo',
                        hintText: 'Votre nom affiché publiquement',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: _pseudoValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
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
                        prefixIcon: const Icon(Icons.lock_outline),
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
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalInfoPage(initialTab: 2),
                          ),
                        ),
                        child: const Text(
                          'Mentions légales',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFF6600),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFFF6600),
                          ),
                        ),
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
