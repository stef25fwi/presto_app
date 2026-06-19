import 'dart:math' as math;

import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  static const String routeName = '/login';

  const LoginPage({
    super.key,
    this.onLogin,
    this.onForgotPassword,
    this.onCreateAccount,
    this.onGoogle,
    this.onApple,
  });

  final Future<void> Function(String identifier, String password)? onLogin;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class ConnexionPage extends LoginPage {
  static const String routeName = LoginPage.routeName;
  const ConnexionPage({super.key});
}

class LoginScreen extends LoginPage {
  static const String routeName = LoginPage.routeName;
  const LoginScreen({super.key});
}

class SignInPage extends LoginPage {
  static const String routeName = LoginPage.routeName;
  const SignInPage({super.key});
}

class SignInScreen extends LoginPage {
  static const String routeName = LoginPage.routeName;
  const SignInScreen({super.key});
}

class AccountLoginPage extends LoginPage {
  static const String routeName = LoginPage.routeName;
  const AccountLoginPage({super.key});
}

class _LoginPageState extends State<LoginPage> {
  static const Color _orange = Color(0xFFFF6600);
  static const Color _blue = Color(0xFF1A73E8);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _fieldBorder = Color(0xFFD8DEE8);

  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '✅ ACTIVE_LOGIN_PAGE_PIXEL_PERFECT_ILI_PRESTO '
      'file=lib/pages/auth/login_page.dart route=/login',
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (widget.onLogin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connexion prête : branche ici ton service Auth existant.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await widget.onLogin!(
        _identifierController.text.trim(),
        _passwordController.text,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fallbackAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label : action prête à brancher.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final shortest = media.size.shortestSide;

    final isTabletOrDesktop = width >= 700;
    final cardWidth = math.min(width - 32, isTabletOrDesktop ? 430.0 : 398.0);
    final logoSize = shortest < 380 ? 40.0 : 50.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTabletOrDesktop ? 32 : 16,
                  vertical: isTabletOrDesktop ? 32 : 20,
                ),
                child: Container(
                  width: cardWidth,
                  constraints: BoxConstraints(
                    minHeight: math.min(
                      height - media.padding.vertical - 40,
                      760,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.95),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.10),
                        blurRadius: 36,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.92),
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTabletOrDesktop ? 30 : 24,
                      isTabletOrDesktop ? 48 : 42,
                      isTabletOrDesktop ? 30 : 24,
                      isTabletOrDesktop ? 34 : 28,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Logo(fontSize: logoSize),
                          const SizedBox(height: 18),
                          const Text(
                            'Connectez-vous pour consulter,\npublier et gérer vos annonces.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF2F3747),
                              fontSize: 18,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.15,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _InputField(
                            controller: _identifierController,
                            hintText: 'E-mail ou numéro de téléphone',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) {
                                return 'Renseigne ton e-mail ou ton numéro.';
                              }
                              if (text.length < 5) {
                                return 'Identifiant trop court.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _InputField(
                            controller: _passwordController,
                            hintText: 'Mot de passe',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Renseigne ton mot de passe.';
                              }
                              if ((value ?? '').length < 6) {
                                return 'Mot de passe trop court.';
                              }
                              return null;
                            },
                            suffix: IconButton(
                              splashRadius: 22,
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF4B5563),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _TextLink(
                              text: 'Mot de passe oublié ?',
                              onTap: widget.onForgotPassword ??
                                  () => _fallbackAction('Mot de passe oublié'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 62,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _orange,
                                disabledBackgroundColor:
                                    _orange.withOpacity(0.55),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: _orange.withOpacity(0.32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _loading
                                    ? const SizedBox(
                                        key: ValueKey('loader'),
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        key: ValueKey('label'),
                                        'Se connecter',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const _DividerOr(),
                          const SizedBox(height: 22),
                          _SocialButton(
                            label: 'Continuer avec Google',
                            icon: const _GoogleIcon(),
                            onPressed: widget.onGoogle ??
                                () => _fallbackAction('Connexion Google'),
                          ),
                          const SizedBox(height: 14),
                          _SocialButton(
                            label: 'Continuer avec Apple',
                            icon: const Text(
                              '',
                              style: TextStyle(
                                fontSize: 29,
                                height: 1,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: widget.onApple ??
                                () => _fallbackAction('Connexion Apple'),
                          ),
                          const SizedBox(height: 30),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Vous n’avez pas de compte ? ',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              _TextLink(
                                text: 'Créer un compte',
                                onTap: widget.onCreateAccount ??
                                    () => _fallbackAction('Créer un compte'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 34),
                          const _LegalLine(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 8,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.001,
                child: Text('ACTIVE_LOGIN_PAGE_PIXEL_PERFECT_ILI_PRESTO'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FBFF),
            Color(0xFFFFFFFF),
            Color(0xFFEAF3FF),
          ],
          stops: [0.0, 0.54, 1.0],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            right: -190,
            bottom: -210,
            child: _BlueBlob(size: 520),
          ),
          Positioned(
            right: 26,
            top: 22,
            child: _DotGrid(color: Color(0xFF1A73E8)),
          ),
          Positioned(
            left: -220,
            top: -260,
            child: _OrangeRing(size: 520),
          ),
          Positioned(
            left: 32,
            bottom: 34,
            child: _DotGrid(color: Color(0xFFFF6600), small: true),
          ),
        ],
      ),
    );
  }
}

class _BlueBlob extends StatelessWidget {
  const _BlueBlob({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1A73E8),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _OrangeRing extends StatelessWidget {
  const _OrangeRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFF6600), width: 1.2),
      ),
    );
  }
}

class _DotGrid extends StatelessWidget {
  const _DotGrid({
    required this.color,
    this.small = false,
  });

  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final dot = small ? 4.0 : 4.2;
    final gap = small ? 14.0 : 17.0;
    final count = small ? 4 : 6;

    return SizedBox(
      width: count * gap,
      height: count * gap,
      child: Wrap(
        spacing: gap - dot,
        runSpacing: gap - dot,
        children: List.generate(
          count * count,
          (_) => Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: color.withOpacity(0.85),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'iliprestō',
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 0.95,
            letterSpacing: -1.7,
            fontFamilyFallback: const ['Inter', 'Roboto', 'Arial'],
          ),
          children: const [
            TextSpan(
              text: 'ili',
              style: TextStyle(color: Color(0xFFFF6600)),
            ),
            TextSpan(
              text: 'prestō',
              style: TextStyle(color: Color(0xFF1A73E8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  static const Color _fieldBorder = Color(0xFFD8DEE8);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction:
          obscureText ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF7B8190),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: Color(0xFF4B5563), size: 24),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _fieldBorder, width: 1.35),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _fieldBorder, width: 1.35),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.55),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.35),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.55),
        ),
      ),
    );
  }
}

class _DividerOr extends StatelessWidget {
  const _DividerOr();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFD9DEE8), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'ou',
            style: TextStyle(
              color: Color(0xFF374151),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD9DEE8), thickness: 1)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFFD8DEE8), width: 1.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 42,
                child: Center(child: icon),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 27,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF006DFF),
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _LegalLine extends StatelessWidget {
  const _LegalLine();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        text: 'En continuant, vous acceptez les ',
        children: [
          TextSpan(
            text: 'Conditions d’utilisation',
            style: TextStyle(
              color: Color(0xFF006DFF),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: '\net la '),
          TextSpan(
            text: 'Politique de confidentialité.',
            style: TextStyle(
              color: Color(0xFF006DFF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 12.8,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
