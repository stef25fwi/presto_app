import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_core.dart';
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
  static const Color _pageTint = Color(0xFFFFF4EC);
  static const Color _cardTint = Color(0xFFFFFBF7);
  static const Color _ink = Color(0xFF1F2440);
  static const Color _muted = Color(0xFF786B61);

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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kPrestoOrange),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: kPrestoOrange.withValues(alpha: 0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: kPrestoOrange.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kPrestoOrange, width: 1.6),
      ),
    );
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
      backgroundColor: _pageTint,
      appBar: AppBar(
        title: const Text('Mon compte'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kPrestoOrange.withValues(alpha: 0.18),
                    _pageTint,
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kPrestoOrange.withValues(alpha: 0.30),
                    kPrestoOrange.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardTint,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: kPrestoOrange.withValues(alpha: 0.16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x2A874B17),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                kPrestoOrange,
                                const Color(0xFFFF9A3D),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kPrestoOrange.withValues(alpha: 0.28),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_circle_outlined,
                            size: 46,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: kPrestoOrange.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _isSignup
                                ? 'Nouveau compte Prest\'o'
                                : 'Connexion rapide et securisee',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: kPrestoOrange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _isSignup
                              ? 'Creez votre espace en quelques secondes'
                              : 'Retrouvez votre compte Prest\'o',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Connectez-vous pour charger votre profil officiel et retrouver vos messages, annonces et favoris.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: _fieldDecoration(
                            label: 'E-mail',
                            icon: Icons.email_outlined,
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: _fieldDecoration(
                            label: 'Mot de passe',
                            icon: Icons.lock_outline,
                          ),
                          validator: _validatePassword,
                          onFieldSubmitted: (_) =>
                              _isLoading ? null : _submitEmailAuth(),
                        ),
                        if (_isSignup) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordConfirmController,
                            obscureText: true,
                            decoration: _fieldDecoration(
                              label: 'Confirmer le mot de passe',
                              icon: Icons.lock_reset_outlined,
                            ),
                            validator: _validatePassword,
                            onFieldSubmitted: (_) =>
                                _isLoading ? null : _submitEmailAuth(),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: kPrestoOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submitEmailAuth,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            _isSignup ? 'Creer le compte' : 'Se connecter',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: kPrestoOrange.withValues(alpha: 0.22),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'ou',
                                style: TextStyle(
                                  color: _muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: kPrestoOrange.withValues(alpha: 0.22),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _ink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            side: BorderSide(
                              color: kPrestoOrange.withValues(alpha: 0.18),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              _GoogleLogoMark(size: 20),
                              SizedBox(width: 12),
                              Text(
                                'Continuer avec Google',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() => _isSignup = !_isSignup);
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: kPrestoOrange,
                          ),
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
          ),
        ],
      ),
    );
  }
}

class _GoogleLogoMark extends StatelessWidget {
  const _GoogleLogoMark({required this.size});

  final double size;

  static const String _googleGlyph = '''
<svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M21.805 12.23c0-.682-.055-1.367-.173-2.037H12v3.856h5.51a4.71 4.71 0 0 1-2.04 3.09v2.57h3.31c1.943-1.788 3.025-4.43 3.025-7.479Z" fill="#4285F4"/>
  <path d="M12 22c2.755 0 5.078-.905 6.77-2.46l-3.31-2.57c-.92.625-2.107.98-3.46.98-2.667 0-4.927-1.8-5.734-4.22H2.85v2.65A10.225 10.225 0 0 0 12 22Z" fill="#34A853"/>
  <path d="M6.266 13.73A6.145 6.145 0 0 1 5.945 12c0-.6.11-1.18.32-1.73V7.62H2.85A10.003 10.003 0 0 0 1.8 12c0 1.61.385 3.136 1.05 4.38l3.416-2.65Z" fill="#FBBC04"/>
  <path d="M12 6.05c1.5 0 2.848.516 3.908 1.53l2.93-2.93C17.074 2.995 14.75 2 12 2 7.992 2 4.53 4.297 2.85 7.62l3.416 2.65C7.073 7.85 9.333 6.05 12 6.05Z" fill="#EA4335"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _googleGlyph,
      width: size,
      height: size,
    );
  }
}