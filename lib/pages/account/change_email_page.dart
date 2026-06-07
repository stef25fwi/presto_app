import 'package:flutter/material.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/auth_service.dart';

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  static const routeName = '/account/change-email';

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _newEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AuthService.instance.requestEmailChange(
        currentPassword: _passwordCtrl.text,
        newEmail: _newEmailCtrl.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien de validation envoyé au nouvel email.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.message(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Changer mon email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Pour changer ton email, confirme ton mot de passe puis valide le lien reçu sur la nouvelle adresse.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Nouvel email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Nouvel email obligatoire.';
                  if (!text.contains('@')) return 'Email invalide.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe actuel',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_hidePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Mot de passe obligatoire.';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Envoyer le lien de validation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
