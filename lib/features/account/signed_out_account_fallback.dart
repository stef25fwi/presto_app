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

import 'package:presto_app/widgets/pro_siret_signup_section.dart';
import '../../app/presto_design_tokens.dart';

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
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _didLogOpen = false;
  bool _isLoading = false;
  bool _isSignup = false;
  bool _isBusinessSignup = false;
  String _signupSiretRaw = '';
  String? _verifiedSignupSiret;
  String? _verifiedSignupCompanyName;

  String get _signupSiretClean => _signupSiretRaw.replaceAll(RegExp(r'\D'), '');
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _trackLogin({String? authMethod, bool isNewUser = false}) async {
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
    if (_isSignup && _isBusinessSignup) {
      final cleanedSiret = _signupSiretClean;
      if (cleanedSiret.length != 14 ||
          _verifiedSignupSiret == null ||
          _verifiedSignupSiret != cleanedSiret) {
        showErrorSnackBar(
          context,
          'Vérifiez votre SIRET avant de créer le compte entreprise.',
        );
        return;
      }
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isSignup) {
        final displayName = _isBusinessSignup
            ? _displayNameController.text.trim()
            : '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
        await _emailAuthService.register(
          displayName: displayName,
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
            builder: (_) => ProProfilePage(
              initialSiret: _signupSiretClean,
              initialCompanyName: _verifiedSignupCompanyName,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential' ||
          error.code == 'invalid-login-credentials') {
        // clear password after failed login
        _passwordController.clear();
      }

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
        context,
        mapPasswordResetSuccessMessage(_emailController.text),
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
          details: <String, Object?>{'source': widget.source},
        );
      });
    }

    const proOrange = Color(0xFFFF6600);
    const statusBlue = Color(0xFF1A73E8);
    const textDark = Color(0xFF1F2937);
    const textMuted = Color(0xFF6B7280);
    const borderColor = Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        surfaceTintColor: const Color(0xFFFF6600),
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: proOrange,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: const Text(
          'Mon compte',
          style: TextStyle(color: PrestoColors.textOnOrange),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFFF6600),
        // Le blanc sur l'orange de marque plafonne à 2,94:1.
        foregroundColor: PrestoColors.textOnOrange,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isFullBleed = constraints.maxWidth < 700;
            final horizontalPadding = isFullBleed ? 0.0 : 16.0;
            final verticalPadding = isFullBleed ? 0.0 : 12.0;
            final cardRadius = isFullBleed ? 0.0 : 24.0;
            final maxCardWidth = isFullBleed ? constraints.maxWidth : 560.0;
            final availableHeight =
                (constraints.maxHeight - (verticalPadding * 2)).clamp(
              420.0,
              double.infinity,
            );

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxCardWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    verticalPadding,
                  ),
                  child: SizedBox(
                    height: availableHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(color: borderColor),
                        boxShadow: isFullBleed
                            ? const []
                            : const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 28,
                                  offset: Offset(0, 16),
                                ),
                              ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Form(
                            key: _formKey,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: availableHeight - 48,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    // Un `Row` figé débordait de 30 px au
                                    // repos et de 464 px à 320 px avec un
                                    // texte agrandi : le bloc de marque passe
                                    // à la ligne au lieu de déborder.
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 14,
                                      runSpacing: 8,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.asset(
                                            'assets/images/logowebp.webp',
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const Text(
                                          'iliprestō',
                                          style: TextStyle(
                                            color: PrestoColors.brandOrangeText,
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _isSignup
                                          ? 'Créer un compte'
                                          : 'Connexion à mon compte',
                                      style: const TextStyle(
                                        color: textDark,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                      ),
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
                                                      () => _isBusinessSignup =
                                                          false,
                                                    ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _AccountTypeButton(
                                            selected: _isBusinessSignup,
                                            icon:
                                                Icons.business_center_outlined,
                                            label: 'Entreprise',
                                            onTap: _isLoading
                                                ? null
                                                : () => setState(
                                                      () => _isBusinessSignup =
                                                          true,
                                                    ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    ProSiretSignupSection(
                                      visible: _isBusinessSignup,
                                      onSiretChanged: (value) {
                                        final cleaned = value.replaceAll(
                                          RegExp(r'\D'),
                                          '',
                                        );
                                        setState(() {
                                          _signupSiretRaw = value;
                                          if (_verifiedSignupSiret != cleaned) {
                                            _verifiedSignupSiret = null;
                                            _verifiedSignupCompanyName = null;
                                          }
                                        });
                                      },
                                      onVerified: (result) {
                                        final cleaned = _signupSiretClean;
                                        setState(() {
                                          _verifiedSignupSiret = cleaned;
                                          _verifiedSignupCompanyName =
                                              result.companyName;
                                        });
                                        showSuccessSnackBar(
                                          context,
                                          result.companyName.isNotEmpty
                                              ? 'SIRET vérifié : ${result.companyName}'
                                              : 'SIRET vérifié',
                                        );
                                      },
                                    ),
                                    if (_isBusinessSignup) ...[
                                      AuthTextField(
                                        controller: _displayNameController,
                                        label: 'Nom du contact',
                                        icon: Icons.badge_outlined,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.name,
                                        ],
                                        validator: AuthValidators.displayName,
                                        enabled: !_isLoading,
                                      ),
                                    ] else ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: AuthTextField(
                                              controller: _firstNameController,
                                              label: 'Prénom',
                                              icon:
                                                  Icons.person_outline_rounded,
                                              textInputAction:
                                                  TextInputAction.next,
                                              autofillHints: const [
                                                AutofillHints.givenName,
                                              ],
                                              validator:
                                                  AuthValidators.firstName,
                                              enabled: !_isLoading,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: AuthTextField(
                                              controller: _lastNameController,
                                              label: 'Nom',
                                              icon:
                                                  Icons.person_outline_rounded,
                                              textInputAction:
                                                  TextInputAction.next,
                                              autofillHints: const [
                                                AutofillHints.familyName,
                                              ],
                                              validator:
                                                  AuthValidators.lastName,
                                              enabled: !_isLoading,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
                                                () => _obscurePassword =
                                                    !_obscurePassword,
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
                                  if (!_isSignup) ...[
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed:
                                            _isLoading ? null : _resetPassword,
                                        child: const Text(
                                          'Mot de passe oublié ?',
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (_isSignup) ...[
                                    const SizedBox(height: 12),
                                    AuthTextField(
                                      controller: _passwordConfirmController,
                                      label: 'Confirmer le mot de passe',
                                      icon: Icons.lock_reset_outlined,
                                      obscureText: _obscurePasswordConfirm,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.newPassword,
                                      ],
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
                                      onFieldSubmitted: (_) => _isLoading
                                          ? null
                                          : _submitEmailAuth(),
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
                                    onPressed:
                                        _isLoading ? null : _signInWithGoogle,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: statusBlue,
                                      side: const BorderSide(
                                        color: borderColor,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const _GoogleLogo(size: 22),
                                    label: const Text('Continuer avec Google'),
                                  ),
                                  if (!_isSignup) ...[
                                    const SizedBox(height: 8),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
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
                  ),
                ),
              ),
            );
          },
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
          color: selected ? const Color(0xFFFFF3EA) : const Color(0xFFFFFFFF),
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
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.16;
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Logo Google "G" simplifié, multicolore, sans asset externe.
    canvas.drawArc(rect, -0.18, 1.36, false, arcPaint(_blue));
    canvas.drawArc(rect, 1.10, 1.15, false, arcPaint(_green));
    canvas.drawArc(rect, 2.18, 0.82, false, arcPaint(_yellow));
    canvas.drawArc(rect, 2.90, 1.18, false, arcPaint(_red));
    canvas.drawArc(rect, 4.00, 0.92, false, arcPaint(_blue));

    final horizontalPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final y = size.height * 0.52;
    canvas.drawLine(
      Offset(size.width * 0.52, y),
      Offset(size.width * 0.88, y),
      horizontalPaint,
    );

    final verticalPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.88, y),
      Offset(size.width * 0.88, size.height * 0.68),
      verticalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
