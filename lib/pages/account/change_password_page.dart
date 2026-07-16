import 'package:flutter/material.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/auth_service.dart';

typedef ChangePasswordAction = Future<void> Function({
  required String currentPassword,
  required String newPassword,
});

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    super.key,
    this.onChangePassword,
  });

  static const routeName = '/account/change-password';

  final ChangePasswordAction? onChangePassword;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();

  bool _loading = false;
  bool _hideCurrent = true;
  bool _hideNew = true;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final changePassword =
          widget.onChangePassword ?? AuthService.instance.changePassword;
      await changePassword(
        currentPassword: _currentPasswordCtrl.text,
        newPassword: _newPasswordCtrl.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe modifié.')),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6600),
        foregroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: const Color(0xFFFF6600),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Changer mot de passe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _currentPasswordCtrl,
                obscureText: _hideCurrent,
                decoration: InputDecoration(
                  labelText: 'Mot de passe actuel',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hideCurrent ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Mot de passe actuel obligatoire.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordCtrl,
                obscureText: _hideNew,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_hideNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hideNew = !_hideNew),
                  ),
                ),
                validator: _passwordValidator,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Modifier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
