import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class PrestoPremiumAuthPage extends StatefulWidget {
  const PrestoPremiumAuthPage({super.key});

  @override
  State<PrestoPremiumAuthPage> createState() => _PrestoPremiumAuthPageState();
}

class _PrestoPremiumAuthPageState extends State<PrestoPremiumAuthPage>
    with TickerProviderStateMixin {
  static const _anim = Duration(milliseconds: 160);

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _emailExpanded = false;
  bool _loadingGoogle = false;
  bool _loadingApple = false;
  bool _loadingEmail = false;
  bool _obscure = true;
  bool _isSignUpMode = false; // Mode inscription ou connexion

  bool get _showApple {
    // Apple button: iOS/macOS + Web (si tu gères Apple sur web)
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

  // ---------- ACTIONS (branche tes services ici) ----------
  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      // Authentification Google via Firebase (Web et Mobile)
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();

      if (kIsWeb) {
        // Sur Web: popup OAuth
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // Sur Mobile: redirect OAuth
        await FirebaseAuth.instance.signInWithRedirect(googleProvider);
      }

      if (!mounted) return;
      // Navigation après connexion réussie
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      String errorMsg = "Erreur Google";
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'popup-closed-by-user':
          case 'cancelled-popup-request':
            return; // Annulation silencieuse
          case 'popup-blocked':
            errorMsg = "Pop-up bloquée. Autorise les pop-ups.";
            break;
          case 'account-exists-with-different-credential':
            errorMsg = "Ce compte existe avec une autre méthode.";
            break;
          default:
            errorMsg = "Erreur Google: ${e.message}";
        }
      }
      _toastError(errorMsg);
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loadingApple = true);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      if (!mounted) return;
      // Navigation après connexion réussie
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      _toastError("Erreur Apple: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  Future<void> _signInWithEmailPassword() async {
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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;
      // Navigation après connexion réussie
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      String errorMsg = "Erreur de connexion";
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMsg = "Aucun compte trouvé avec cet email.";
            break;
          case 'wrong-password':
            errorMsg = "Mot de passe incorrect.";
            break;
          case 'invalid-email':
            errorMsg = "Format d'email invalide.";
            break;
          case 'user-disabled':
            errorMsg = "Ce compte a été désactivé.";
            break;
          default:
            errorMsg = "Erreur: ${e.message}";
        }
      }
      _toastError(errorMsg);
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      _toastError("Renseigne ton email pour recevoir le lien.");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Lien de réinitialisation envoyé ✅\nVérifie ta boîte mail."),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMsg = "Erreur lors de l'envoi";
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMsg = "Aucun compte trouvé avec cet email.";
            break;
          case 'invalid-email':
            errorMsg = "Format d'email invalide.";
            break;
          default:
            errorMsg = "Erreur: ${e.message}";
        }
      }
      _toastError(errorMsg);
    }
  }

  Future<void> _goToSignUp() async {
    setState(() => _isSignUpMode = !_isSignUpMode);
  }

  Future<void> _createAccount() async {
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
      // Création du compte
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // Envoi de l'email de vérification (optionnel)
      await userCredential.user?.sendEmailVerification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Compte créé ✅\nEmail de vérification envoyé."),
          duration: Duration(seconds: 3),
        ),
      );

      // Navigation après inscription réussie
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      String errorMsg = "Erreur lors de la création";
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMsg = "Cet email est déjà utilisé.\nEssaie de te connecter.";
            break;
          case 'invalid-email':
            errorMsg = "Format d'email invalide.";
            break;
          case 'weak-password':
            errorMsg = "Mot de passe trop faible.";
            break;
          default:
            errorMsg = "Erreur: ${e.message}";
        }
      }
      _toastError(errorMsg);
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  void _discoverPro() {
    Navigator.pushNamed(context, '/pro');
  }

  void _toastError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    const prestoOrange = Color(0xFFFF6600);
    const prestoBlue = Color(0xFF1A73E8);
    const textMuted = Color(0xFF6B7280);

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
                  // 1) HEADER PREMIUM (léger)
                  _HeaderPremium(
                    title: "Bienvenue sur Prestō",
                    subtitle:
                        "Le moyen le plus rapide de trouver ou proposer un service",
                    accent: prestoOrange,
                    muted: textMuted,
                  ),

                  const SizedBox(height: 18),

                  // 2) ACTION PRINCIPALE — CONNEXION EXPRESS (carte dominante)
                  _PremiumCard(
                    radius: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PrimaryProviderButton(
                          label: "Continuer avec Google",
                          loading: _loadingGoogle,
                          onTap: _loadingAny ? null : _signInWithGoogle,
                          variant: _ProviderVariant.google,
                        ),
                        const SizedBox(height: 12),
                        if (_showApple) ...[
                          _PrimaryProviderButton(
                            label: "Continuer avec Apple",
                            loading: _loadingApple,
                            onTap: _loadingAny ? null : _signInWithApple,
                            variant: _ProviderVariant.apple,
                          ),
                          const SizedBox(height: 10),
                        ],
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

                  const SizedBox(height: 16),

                  // Séparateur premium "ou"
                  _OrDivider(muted: textMuted),

                  const SizedBox(height: 14),

                  // 3) CONNEXION CLASSIQUE (repliée par défaut)
                  _PremiumCard(
                    radius: 24,
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _loadingAny
                              ? null
                              : () => setState(
                                  () => _emailExpanded = !_emailExpanded),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.mail_outline, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isSignUpMode
                                        ? "Créer un compte avec email"
                                        : "Se connecter avec un email",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _emailExpanded ? 0.5 : 0.0,
                                  duration: _anim,
                                  child: const Icon(Icons.expand_more),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: _anim,
                          curve: Curves.easeOut,
                          child: _emailExpanded
                              ? Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 8, 12, 6),
                                  child: Column(
                                    children: [
                                      _Input(
                                        controller: _emailCtrl,
                                        hint: "Adresse email",
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        enabled: !_loadingAny,
                                      ),
                                      const SizedBox(height: 10),
                                      _Input(
                                        controller: _passCtrl,
                                        hint: "Mot de passe",
                                        enabled: !_loadingAny,
                                        obscureText: _obscure,
                                        suffix: IconButton(
                                          onPressed: _loadingAny
                                              ? null
                                              : () => setState(
                                                  () => _obscure = !_obscure),
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            size: 20,
                                            color: textMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Bouton dynamique selon le mode
                                      _MainActionButton(
                                        label: _isSignUpMode
                                            ? "Créer mon compte"
                                            : "Se connecter",
                                        loading: _loadingEmail,
                                        color: prestoOrange,
                                        onTap: _loadingAny
                                            ? null
                                            : (_isSignUpMode
                                                ? _createAccount
                                                : _signInWithEmailPassword),
                                      ),

                                      const SizedBox(height: 10),

                                      // Liens selon le mode
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (!_isSignUpMode) ...[
                                            _LinkText(
                                              text: "Mot de passe oublié ?",
                                              color: prestoBlue,
                                              onTap: _loadingAny
                                                  ? null
                                                  : _resetPassword,
                                            ),
                                            const Text("   •   ",
                                                style: TextStyle(
                                                    color: textMuted)),
                                          ],
                                          _LinkText(
                                            text: _isSignUpMode
                                                ? "J'ai déjà un compte"
                                                : "Créer un compte",
                                            color: prestoBlue,
                                            onTap: _loadingAny
                                                ? null
                                                : _goToSignUp,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4) PROFIL PRO — SECOND PLAN
                  _SoftInfoCard(
                    title: "Vous êtes un professionnel ?",
                    body:
                        "Publiez plus facilement et accédez\naux options Pro.",
                    badge: "Bientôt disponible",
                    onTap: _discoverPro,
                  ),

                  const SizedBox(height: 18),

                  // 5) FOOTER MINIMAL
                  Text(
                    "En continuant, vous acceptez les\nConditions d'utilisation • Politique de confidentialité",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      height: 1.35,
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

  bool get _loadingAny => _loadingGoogle || _loadingApple || _loadingEmail;
}

// ---------------- WIDGETS ----------------

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
        // mini "logo" très discret (optionnel)
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.bolt, color: accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14.5,
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

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final double radius;

  const _PremiumCard({required this.child, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.05)),
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
                height: 1, thickness: 1, color: muted.withOpacity(0.20))),
        const SizedBox(width: 10),
        Text("ou", style: TextStyle(fontSize: 13, color: muted)),
        const SizedBox(width: 10),
        Expanded(
            child: Divider(
                height: 1, thickness: 1, color: muted.withOpacity(0.20))),
      ],
    );
  }
}

enum _ProviderVariant { google, apple }

class _PrimaryProviderButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final _ProviderVariant variant;

  const _PrimaryProviderButton({
    required this.label,
    required this.loading,
    required this.onTap,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = variant == _ProviderVariant.apple;

    final bg = isApple ? Colors.black : Colors.white;
    final fg = isApple ? Colors.white : Colors.black87;
    final border =
        isApple ? Colors.transparent : Colors.black.withOpacity(0.14);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
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
                  Icon(isApple ? Icons.apple : Icons.g_mobiledata,
                      color: fg, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MainActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final Color color;
  final VoidCallback? onTap;

  const _MainActionButton({
    required this.label,
    required this.loading,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  const _Input({
    required this.controller,
    required this.hint,
    required this.enabled,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: Colors.black.withOpacity(0.22)),
        ),
        suffixIcon: suffix,
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _LinkText({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SoftInfoCard extends StatelessWidget {
  final String title;
  final String body;
  final String badge;
  final VoidCallback onTap;

  const _SoftInfoCard({
    required this.title,
    required this.body,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const prestoOrange = Color(0xFFFF6600);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: prestoOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                const Icon(Icons.work_outline, color: prestoOrange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: prestoOrange.withOpacity(0.55)),
                      color: Colors.transparent,
                    ),
                    child: const Text(
                      "Découvrir le compte Pro",
                      style: TextStyle(
                        color: prestoOrange,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
