import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/auth_error_mapper.dart';
import '../../services/auth_service.dart';

typedef DeleteAccountAction = Future<void> Function({String? password});

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    super.key,
    this.usesPasswordProviderOverride,
    this.deleteAccountAction,
  });

  static const routeName = '/account/delete';

  @visibleForTesting
  final bool? usesPasswordProviderOverride;

  @visibleForTesting
  final DeleteAccountAction? deleteAccountAction;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  bool get _usesPasswordProvider {
    final override = widget.usesPasswordProviderOverride;
    if (override != null) return override;

    final user = FirebaseAuth.instance.currentUser;
    return user?.providerData
            .any((provider) => provider.providerId == 'password') ==
        true;
  }

  Future<void> _runDeleteAccount({String? password}) {
    final override = widget.deleteAccountAction;
    if (override != null) return override(password: password);
    return AuthService.instance.deleteCurrentAccount(password: password);
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await _runDeleteAccount(
        password: _usesPasswordProvider ? _passwordCtrl.text : null,
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    final usesPasswordProvider = _usesPasswordProvider;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6600),
        foregroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: const Color(0xFFFF6600),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Supprimer mon compte'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Cette action est définitive. Ton abonnement sera annulé, tes données privées seront supprimées et ton profil sera anonymisé dans les conversations conservées.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (usesPasswordProvider) ...[
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Afficher le mot de passe'
                          : 'Masquer le mot de passe',
                      icon: Icon(
                        _hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return 'Mot de passe obligatoire.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ] else ...[
                const Card(
                  elevation: 0,
                  color: Color(0xFFFFF3EA),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Compte Google ou Apple : pour ta sécurité, la suppression est autorisée uniquement après une connexion récente. Reconnecte-toi puis reviens ici si un message te le demande.',
                      style: TextStyle(height: 1.35),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _confirmCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Tape SUPPRIMER',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim() != 'SUPPRIMER') {
                    return 'Tape SUPPRIMER pour confirmer.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading ? null : _delete,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Supprimer définitivement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
