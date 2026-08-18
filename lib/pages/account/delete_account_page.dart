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

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  bool _hasProvider(String providerId) {
    return _currentUser?.providerData
            .any((provider) => provider.providerId == providerId) ==
        true;
  }

  bool get _usesPasswordProvider {
    final override = widget.usesPasswordProviderOverride;
    if (override != null) return override;
    return _hasProvider('password');
  }

  String get _federatedProviderLabel {
    final labels = <String>[];
    if (_hasProvider('google.com')) labels.add('Google');
    if (_hasProvider('apple.com')) labels.add('Apple');
    if (_hasProvider('facebook.com')) labels.add('Facebook');
    return labels.isEmpty ? 'votre fournisseur de connexion' : labels.join(', ');
  }

  Future<UserCredential> _reauthenticateWithProvider(
    AuthProvider provider,
  ) async {
    final user = _currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Utilisateur non connecté.',
      );
    }

    if (kIsWeb) {
      return user.reauthenticateWithPopup(provider);
    }
    return user.reauthenticateWithProvider(provider);
  }

  Future<void> _prepareFederatedDeletion() async {
    // Les tests peuvent injecter l'action de suppression sans Firebase réel.
    if (widget.deleteAccountAction != null) return;

    final user = _currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'Utilisateur non connecté.',
      );
    }

    // Apple exige une révocation du jeton lors de la suppression du compte.
    // Firebase ne conserve pas le jeton Apple : on réauthentifie donc l'utilisateur
    // pour obtenir un nouveau code d'autorisation, puis on le révoque avant de
    // déclencher l'effacement serveur.
    if (_hasProvider('apple.com')) {
      final credential = await _reauthenticateWithProvider(AppleAuthProvider());
      final authorizationCode =
          credential.additionalUserInfo?.authorizationCode?.trim() ?? '';
      if (authorizationCode.isEmpty) {
        throw FirebaseAuthException(
          code: 'apple-token-revocation-failed',
          message:
              'La révocation Apple n’a pas pu être préparée. Reconnecte-toi avec Apple puis réessaie.',
        );
      }
      await FirebaseAuth.instance
          .revokeTokenWithAuthorizationCode(authorizationCode);
      return;
    }

    final lastSignIn = user.metadata.lastSignInTime;
    final isRecent = lastSignIn != null &&
        DateTime.now().difference(lastSignIn) <= const Duration(minutes: 10);
    if (isRecent || _usesPasswordProvider) return;

    // Pour Google/Facebook, une reconnexion interactive évite d'envoyer
    // l'utilisateur ailleurs puis de lui demander de revenir manuellement.
    if (_hasProvider('google.com')) {
      await _reauthenticateWithProvider(GoogleAuthProvider());
      return;
    }
    if (_hasProvider('facebook.com')) {
      await _reauthenticateWithProvider(FacebookAuthProvider());
      return;
    }

    throw FirebaseAuthException(
      code: 'requires-recent-login',
      message:
          'Reconnecte-toi avec ton fournisseur de connexion avant de supprimer le compte.',
    );
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
      await _prepareFederatedDeletion();
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
    final federatedProviderLabel = _federatedProviderLabel;

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
                'Cette action est définitive. Ton abonnement sera annulé, tes données privées seront supprimées et les données conservées uniquement pour une obligation légale, la sécurité ou un litige seront limitées et anonymisées autant que possible.',
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
              ],
              if (!usesPasswordProvider ||
                  _hasProvider('apple.com') ||
                  _hasProvider('google.com') ||
                  _hasProvider('facebook.com')) ...[
                Card(
                  elevation: 0,
                  color: const Color(0xFFFFF3EA),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Connexion $federatedProviderLabel : une réauthentification peut s’ouvrir automatiquement pour confirmer ton identité. Pour Apple, le jeton de connexion est également révoqué avant la suppression.',
                      style: const TextStyle(height: 1.35),
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
