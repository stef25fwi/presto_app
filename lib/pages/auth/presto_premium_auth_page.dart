import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class PrestoPremiumAuthPage extends StatefulWidget {
  /// Rebranche ici tes fonctions existantes (ou laisse null et branche plus tard)
  final Future<void> Function()? onGoogle;
  final Future<void> Function()? onApple;
  final Future<void> Function(String email, String password)? onEmailLogin;
  final Future<void> Function(String email)? onResetPassword;
  final VoidCallback? onGoToSignup;
  final VoidCallback? onDiscoverPro;

  const PrestoPremiumAuthPage({
    super.key,
    this.onGoogle,
    this.onApple,
    this.onEmailLogin,
    this.onResetPassword,
    this.onGoToSignup,
    this.onDiscoverPro,
  });

  @override
  State<PrestoPremiumAuthPage> createState() => _PrestoPremiumAuthPageState();
}

class _PrestoPremiumAuthPageState extends State<PrestoPremiumAuthPage>
    with TickerProviderStateMixin {
  static const _anim = Duration(milliseconds: 160);

  // Palette (conforme Prestō)
  static const prestoOrange = Color(0xFFFF6600);
  static const prestoBlue = Color(0xFF1A73E8);
  static const textMuted = Color(0xFF6B7280);

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _expandedEmail = true; // visuel de la maquette: email section ouverte
  bool _obscure = true;

  bool _loadingGoogle = false;
  bool _loadingApple = false;
  bool _loadingEmail = false;

  bool get _loadingAny => _loadingGoogle || _loadingApple || _loadingEmail;

  bool get _showApple {
    if (kIsWeb) return true;
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _toastError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _handleGoogle() async {
    if (_loadingAny) return;
    setState(() => _loadingGoogle = true);
    try {
      if (widget.onGoogle != null) {
        await widget.onGoogle!.call();
      } else {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    } catch (e) {
      _toastError("Google: $e");
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _handleApple() async {
    if (_loadingAny) return;
    setState(() => _loadingApple = true);
    try {
      if (widget.onApple != null) {
        await widget.onApple!.call();
      } else {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    } catch (e) {
      _toastError("Apple: $e");
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  Future<void> _handleEmailLogin() async {
    if (_loadingAny) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || !email.contains("@")) {
      _toastError("Entre une adresse email valide.");
      return;
    }
    if (pass.length < 6) {
      _toastError("Mot de passe trop court (min. 6).");
      return;
    }

    setState(() => _loadingEmail = true);
    try {
      if (widget.onEmailLogin != null) {
        await widget.onEmailLogin!.call(email, pass);
      } else {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    } catch (e) {
      _toastError("Email: $e");
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  Future<void> _handleReset() async {
    if (_loadingAny) return;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      _toastError("Renseigne ton email pour recevoir le lien.");
      return;
    }
    try {
      if (widget.onResetPassword != null) {
        await widget.onResetPassword!.call(email);
      } else {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lien de réinitialisation envoyé ✅")),
      );
    } catch (e) {
      _toastError("Reset: $e");
    }
  }

  void _handleSignup() {
    if (_loadingAny) return;
    widget.onGoToSignup?.call();
  }

  void _handleDiscoverPro() {
    widget.onDiscoverPro?.call();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final maxContentW = w > 520 ? 520.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentW),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER (icon + title)
                  _HeaderPremium(
                    title: "Bienvenue sur Prestō",
                    subtitle:
                        "Le moyen le plus rapide de trouver ou proposer un service",
                    accent: prestoOrange,
                    muted: textMuted,
                  ),
                  const SizedBox(height: 18),

                  // Carte providers
                  _CardShell(
                    radius: 22,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProviderButton(
                          variant: _ProviderVariant.google,
                          label: "Continuer avec Google",
                          loading: _loadingGoogle,
                          onTap: _loadingAny ? null : _handleGoogle,
                        ),
                        const SizedBox(height: 12),
                        if (_showApple) ...[
                          _ProviderButton(
                            variant: _ProviderVariant.apple,
                            label: "Continuer avec Apple",
                            loading: _loadingApple,
                            onTap: _loadingAny ? null : _handleApple,
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          "Connexion rapide • sans mot de passe",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Divider OU (long, fin)
                  _OrDivider(muted: textMuted),
                  const SizedBox(height: 16),

                  // Email card
                  _CardShell(
                    radius: 22,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _loadingAny
                              ? null
                              : () => setState(() {
                                    _expandedEmail = !_expandedEmail;
                                  }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.mail_outline, size: 22),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "Se connecter avec un email",
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _expandedEmail ? 0.5 : 0.0,
                                  duration: _anim,
                                  child: const Icon(Icons.expand_more),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSize(
                          duration: _anim,
                          curve: Curves.easeOut,
                          child: _expandedEmail
                              ? Column(
                                  children: [
                                    _SoftField(
                                      controller: _emailCtrl,
                                      hint: "Adresse email",
                                      enabled: !_loadingAny,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 12),
                                    _SoftField(
                                      controller: _passCtrl,
                                      hint: "Mot de passe",
                                      enabled: !_loadingAny,
                                      obscureText: _obscure,
                                      suffix: IconButton(
                                        onPressed: _loadingAny
                                            ? null
                                            : () => setState(() {
                                                  _obscure = !_obscure;
                                                }),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 20,
                                          color: textMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _OrangePrimaryButton(
                                      label: "Se connecter",
                                      loading: _loadingEmail,
                                      onTap: _loadingAny
                                          ? null
                                          : _handleEmailLogin,
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _Link(
                                          text: "Mot de passe oublié ?",
                                          onTap:
                                              _loadingAny ? null : _handleReset,
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10),
                                          child: Text("•",
                                              style: TextStyle(
                                                  color: textMuted,
                                                  fontSize: 16)),
                                        ),
                                        _Link(
                                          text: "Créer un compte",
                                          onTap: _loadingAny
                                              ? null
                                              : _handleSignup,
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pro card
                  _CardShell(
                    radius: 22,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BriefcaseIcon(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Expanded(
                                    child: Text(
                                      "Vous êtes un professionnel ?",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Publiez plus facilement et accédez aux options Pro.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // "Bientôt disponible" (maquette)
                              InkWell(
                                onTap: _handleDiscoverPro,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: prestoOrange,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    "Bientôt disponible",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Footer
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                      children: const [
                        TextSpan(text: "En continuant, vous acceptez les\n"),
                        TextSpan(
                          text: "Conditions d'utilisation",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: " • "),
                        TextSpan(
                          text: "Politique de confidentialité.",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

// ---------------- UI PIECES ----------------

class _HeaderPremium extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Color muted;

  const _HeaderPremium({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.bolt, color: accent, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15.5,
                  color: muted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  const _CardShell({
    required this.child,
    required this.radius,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }
}

class _OrDivider extends StatelessWidget {
  final Color muted;
  const _OrDivider({required this.muted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: muted.withOpacity(0.35),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          "ou",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: muted.withOpacity(0.35),
          ),
        ),
      ],
    );
  }
}

enum _ProviderVariant { google, apple }

class _ProviderButton extends StatelessWidget {
  final _ProviderVariant variant;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _ProviderButton({
    required this.variant,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = variant == _ProviderVariant.apple;
    final bg = isApple ? const Color(0xFF1F2329) : Colors.white;
    final fg = isApple ? Colors.white : const Color(0xFF111827);
    final border =
        isApple ? Colors.transparent : Colors.black.withOpacity(0.14);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ProviderIcon(variant: variant, color: fg),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  final _ProviderVariant variant;
  final Color color;
  const _ProviderIcon({required this.variant, required this.color});

  @override
  Widget build(BuildContext context) {
    // Pas de logos officiels ici (sans assets), on fait un rendu proche:
    if (variant == _ProviderVariant.apple) {
      return Icon(Icons.apple, color: color, size: 22);
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: const Text(
        "G",
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }
}

class _SoftField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _SoftField({
    required this.controller,
    required this.hint,
    required this.enabled,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: Colors.black.withOpacity(0.18)),
        ),
        suffixIcon: suffix,
      ),
    );
  }
}

class _OrangePrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _OrangePrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6600),
          borderRadius: BorderRadius.circular(14),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _Link({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1A73E8),
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BriefcaseIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Icône proche "valise"
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: const Icon(Icons.work, color: Color(0xFFB45309), size: 26),
    );
  }
}
