import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/account_social_auth_actions.dart';
import '../../services/email_action_service.dart';
import '../../services/email_auth_error_mapper.dart';
import '../../services/google_auth_service.dart';
import '../../services/user_profile_bootstrap_service.dart';
import '../../utils/friendly_snackbar.dart';
import '../../utils/runtime_action_logger.dart';

class SignedOutAccountFallback extends StatefulWidget {
  const SignedOutAccountFallback({
    super.key,
    this.source = 'account',
    this.startInSignup = false,
  });

  final String source;
  final bool startInSignup;

  @override
  State<SignedOutAccountFallback> createState() =>
      _SignedOutAccountFallbackState();
}

class _SignedOutAccountFallbackState extends State<SignedOutAccountFallback> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _didLogOpen = false;
  bool _isLoading = false;
  bool _isSignup = false;

  @override
  void initState() {
    super.initState();
    _isSignup = widget.startInSignup;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _trackLogin({
    String? authMethod,
    bool isNewUser = false,
  }) async {
    logRuntimeAction(
      area: 'account',
      action: 'signed-out-fallback-login',
      details: <String, Object?>{
        'source': widget.source,
        'authMethod': authMethod,
        'isNewUser': isNewUser,
      },
    );
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty || !email.contains('@')) {
      return 'Adresse e-mail invalide';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 6) {
      return 'Minimum 6 caracteres';
    }
    return null;
  }

  Future<void> _submitEmailAuth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isSignup && password != _passwordConfirmController.text) {
      showErrorSnackBar(context, 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = _isSignup
          ? await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            )
          : await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
      final user = credential.user ?? _auth.currentUser;
      if (user != null) {
        await UserProfileBootstrapService.ensureUserDocument(
          user: user,
          authMethod: 'email',
          isNewUserHint: _isSignup,
        );
        await _trackLogin(authMethod: 'email', isNewUser: _isSignup);
        if (_isSignup) {
          await EmailActionService.requestEmailVerificationEmail();
        }
      }
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        _isSignup ? 'Compte cree. Verifiez votre e-mail.' : 'Connexion reussie',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        friendlyEmailAuthErrorMessage(
          error.code,
          error.message ?? 'Connexion impossible. Reessayez.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Connexion impossible: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: _auth,
        googleAuthService: _googleAuthService,
        trackLogin: _trackLogin,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_didLogOpen) {
      _didLogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        logRuntimeAction(
          area: 'account',
          action: 'signed-out-fallback-auth',
          details: <String, Object?>{
            'source': widget.source,
          },
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon compte'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_circle_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _isSignup ? 'Creer mon compte' : 'Connexion a mon compte',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connectez-vous pour charger le profil officiel users/{uid}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => _isLoading ? null : _submitEmailAuth(),
                  ),
                  if (_isSignup) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordConfirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      validator: _validatePassword,
                      onFieldSubmitted: (_) =>
                          _isLoading ? null : _submitEmailAuth(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _submitEmailAuth,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(_isSignup ? 'Creer le compte' : 'Se connecter'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('Continuer avec Google'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() => _isSignup = !_isSignup);
                          },
                    child: Text(
                      _isSignup
                          ? 'J\'ai deja un compte'
                          : 'Creer un nouveau compte',
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