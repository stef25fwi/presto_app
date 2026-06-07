import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/presentation/widgets/auth_error_box.dart';
import '../auth/presentation/widgets/auth_primary_button.dart';
import '../auth/presentation/widgets/auth_text_field.dart';
import '../auth/services/auth_service.dart';
import '../auth/validators/auth_validators.dart';
import '../../services/account_social_auth_actions.dart';
import '../../services/email_auth_error_mapper.dart';
import '../../services/google_auth_service.dart';
import '../../utils/friendly_snackbar.dart';
import '../../utils/runtime_action_logger.dart';
import '../../pages/pro_profile_page.dart';

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
  final EmailAuthService _emailAuthService = EmailAuthService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _didLogOpen = false;
  bool _isLoading = false;
  bool _isSignup = false;
  bool _isBusinessSignup = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isSignup = widget.startInSignup;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
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

  Future<void> _submitEmailAuth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isSignup) {
        await _emailAuthService.register(
          displayName: _displayNameController.text,
          email: email,
          password: password,
          createBusinessProfile: _isBusinessSignup,
        );
      } else {
        await _emailAuthService.signIn(email: email, password: password);
      }
      await _trackLogin(authMethod: 'email', isNewUser: _isSignup);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        _isSignup
            ? _isBusinessSignup
                ? 'Compte entreprise créé. Complétez votre profil.'
                : 'Compte créé. Vérifiez votre e-mail.'
            : 'Connexion réussie.',
      );
      if (_isSignup && _isBusinessSignup) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const ProProfilePage(),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = friendlyEmailAuthErrorMessage(
        error.code,
        error.message ?? 'Connexion impossible. Réessayez.',
      );
      setState(() => _errorMessage = message);
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      const message = 'Connexion impossible. Réessayez dans un instant.';
      setState(() => _errorMessage = message);
      showErrorSnackBar(context, message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final emailError = AuthValidators.email(_emailController.text);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _emailAuthService.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      showSuccessSnackBar(
          context, mapPasswordResetSuccessMessage(_emailController.text));
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'E-mail de réinitialisation envoyé.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = friendlyEmailAuthErrorMessage(
        error.code,
        error.message ?? 'Réinitialisation impossible.',
      );
      setState(() => _errorMessage = message);
      showErrorSnackBar(context, message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Réinitialisation impossible. Réessayez.';
      setState(() => _errorMessage = message);
      showErrorSnackBar(context, message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: _auth,
        googleAuthService: _googleAuthService,
        trackLogin: _trackLogin,
      );
    } catch (_) {
      if (!mounted) return;
      const message = 'Connexion Google impossible. Réessayez.';
      setState(() => _errorMessage = message);
      showErrorSnackBar(context, message);
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

    const proOrange = Color(0xFFFF6600);
    const statusBlue = Color(0xFF1A73E8);
    const textDark = Color(0xFF1F2937);
    const textMuted = Color(0xFF6B7280);
    const borderColor = Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: statusBlue,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Text('Mon compte'),
        automaticallyImplyLeading: false,
        backgroundColor: proOrange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6600),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'iliprestō',
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isSignup
                              ? 'Créer un compte'
                              : 'Connexion à mon compte',
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignup
                              ? _isBusinessSignup
                                  ? 'Votre espace entreprise crée un profil complet utilisable pour la vérification, les annonces, les avis et les demandes.'
                                  : 'Créez votre profil utilisateur avec email, pseudo et vérification de compte.'
                              : 'Retrouvez vos annonces, messages, avis et prestations depuis votre profil sécurisé.',
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (_isSignup) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _AccountTypeButton(
                                  selected: !_isBusinessSignup,
                                  icon: Icons.person_outline_rounded,
                                  label: 'Particulier',
                                  onTap: _isLoading
                                      ? null
                                      : () => setState(
                                            () => _isBusinessSignup = false,
                                          ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _AccountTypeButton(
                                  selected: _isBusinessSignup,
                                  icon: Icons.business_center_outlined,
                                  label: 'Entreprise',
                                  onTap: _isLoading
                                      ? null
                                      : () => setState(
                                            () => _isBusinessSignup = true,
                                          ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AuthTextField(
                            controller: _displayNameController,
                            label: _isBusinessSignup
                                ? 'Nom du contact'
                                : 'Nom ou pseudo',
                            icon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: AuthValidators.displayName,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 12),
                        ],
                        AuthTextField(
                          controller: _emailController,
                          label: 'Adresse email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: AuthValidators.email,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 12),
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Mot de passe',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          textInputAction: _isSignup
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: _isSignup
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          validator: AuthValidators.password,
                          enabled: !_isLoading,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Afficher le mot de passe'
                                : 'Masquer le mot de passe',
                            onPressed: _isLoading
                                ? null
                                : () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          onFieldSubmitted: (_) =>
                              _isLoading ? null : _submitEmailAuth(),
                        ),
                        if (_isSignup) ...[
                          const SizedBox(height: 12),
                          AuthTextField(
                            controller: _passwordConfirmController,
                            label: 'Confirmer le mot de passe',
                            icon: Icons.lock_reset_outlined,
                            obscureText: _obscurePasswordConfirm,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) =>
                                AuthValidators.passwordConfirmation(
                              value,
                              _passwordController.text,
                            ),
                            enabled: !_isLoading,
                            suffixIcon: IconButton(
                              tooltip: _obscurePasswordConfirm
                                  ? 'Afficher la confirmation'
                                  : 'Masquer la confirmation',
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(
                                        () => _obscurePasswordConfirm =
                                            !_obscurePasswordConfirm,
                                      ),
                              icon: Icon(
                                _obscurePasswordConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            onFieldSubmitted: (_) =>
                                _isLoading ? null : _submitEmailAuth(),
                          ),
                        ],
                        if ((_errorMessage ?? '').isNotEmpty) ...[
                          const SizedBox(height: 14),
                          AuthErrorBox(message: _errorMessage!),
                        ],
                        const SizedBox(height: 18),
                        AuthPrimaryButton(
                          isLoading: _isLoading,
                          onPressed: _submitEmailAuth,
                          icon: _isSignup
                              ? Icons.person_add_alt_1_rounded
                              : Icons.login_rounded,
                          label: _isSignup
                              ? _isBusinessSignup
                                  ? 'Créer le compte entreprise'
                                  : 'Créer le compte'
                              : 'Se connecter',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: statusBlue,
                            side: const BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.g_mobiledata_rounded),
                          label: const Text('Continuer avec Google'),
                        ),
                        if (!_isSignup) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ],
                        const Divider(height: 28),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isSignup = !_isSignup;
                                    _errorMessage = null;
                                  });
                                },
                          child: Text(
                            _isSignup
                                ? 'J’ai déjà un compte'
                                : 'Créer un nouveau compte',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTypeButton extends StatelessWidget {
  const _AccountTypeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFF6600) : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF3EA) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFFF6600) : const Color(0xFFE5E7EB),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
