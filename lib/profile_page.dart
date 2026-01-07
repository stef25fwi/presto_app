import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'utils/friendly_snackbar.dart';
import 'constants.dart';
import 'widgets/phone_input_field.dart';
import 'pages/legal_info_page.dart';

enum AuthMode { login, signup }

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  AuthMode _authMode = AuthMode.login;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;
  bool _isLoading = false;
  bool _isEditingProfile = false;
  final ScrollController _scrollController = ScrollController();

  // Controllers pour les formulaires
  final _formKeyAuth = GlobalKey<FormState>();
  final _formKeyProfile = GlobalKey<FormState>();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _passwordConfirmCtrl = TextEditingController();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _cpCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _notifNearby = true;
  bool _notifFavorites = true;
  bool _notifAcceptOffer = true;
  bool _notifSystem = true;

  String _accountType = 'Particulier';
  String _language = 'Français';
  String _theme = 'Système';

  // Catégories et sous-catégories
  final Map<String, List<String>> _allCategories = {
    'Jardinage': ['Tondeuse', 'Élagage', 'Entretien'],
    'Peinture': ['Intérieur', 'Extérieur', 'Décoration'],
    'Aide à domicile': ['Ménage', 'Courses', 'Accompagnement'],
    'Plomberie': ['Fuite', 'Radiateur', 'Installation'],
    'Électricité': ['Dépannage', 'Installation', 'Contrôle'],
    'Menuiserie': ['Meuble', 'Porte', 'Fenêtre'],
  };

  // Catégories et sous-catégories favorites sélectionnées
  final Map<String, List<String>> _favoriteCategories = {
    'Jardinage': ['Tondeuse', 'Élagage'],
    'Peinture': ['Intérieur'],
  };

  @override
  void initState() {
    super.initState();
    _authSub = _auth.authStateChanges().listen((user) {
      final email = user?.email;
      if (email != null && email.isNotEmpty && _emailCtrl.text != email) {
        _emailCtrl.text = email;
      }
    });
    
    // Note : la vérification du redirect Google Sign-In est maintenant gérée
    // dans le SplashScreen (main.dart) pour éviter d'être bloqué sur le splash
    // après un redirect. Le résultat sera déjà traité quand on arrive ici.
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _scrollController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _cpCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _onGoogleSignIn() async {
    if (_isLoading) return;
    
    debugPrint('🔵 [AUTH] ========================================');
    debugPrint('🔵 [AUTH] Starting Google Sign-In...');
    debugPrint('🔵 [AUTH] Current user: ${_auth.currentUser?.email ?? "null"}');
    debugPrint('🔵 [AUTH] Platform: ${kIsWeb ? "Web" : "Native"}');
    debugPrint('🔵 [AUTH] Auth Domain: presto-app-74abe.firebaseapp.com');
    
    setState(() => _isLoading = true);
    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      provider.addScope('email');
      provider.addScope('profile');
      
      debugPrint('🔵 [AUTH] Provider configured with scopes: email, profile');

      if (kIsWeb) {
        debugPrint('🔵 [AUTH] Using Web flow (Popup with Redirect fallback)');
        try {
          debugPrint('🔵 [AUTH] Attempting popup sign-in...');
          await _auth.signInWithPopup(provider);
          debugPrint('✅ [AUTH] Popup sign-in successful!');
          debugPrint('✅ [AUTH] User: ${_auth.currentUser?.email}');
          debugPrint('✅ [AUTH] UID: ${_auth.currentUser?.uid}');
          if (!mounted) return;
          showSuccessSnackBar(context, 'Connecté avec Google');
        } catch (popupError) {
          debugPrint("⚠️ [AUTH] POPUP BLOCKED or FAILED");
          debugPrint("⚠️ [AUTH] Error type: ${popupError.runtimeType}");
          debugPrint("⚠️ [AUTH] Error details: $popupError");
          debugPrint("🔄 [AUTH] Fallback to redirect...");
          // Fallback redirect (ex: popup bloquée)
          await _auth.signInWithRedirect(provider);
          debugPrint("🔄 [AUTH] Redirect initiated, browser will redirect now");
          // Le navigateur va rediriger, on ne continue pas l'exécution
          return;
        }
      } else {
        debugPrint('🔵 [AUTH] Using Native provider flow');
        await _auth.signInWithProvider(provider);
        debugPrint('✅ [AUTH] Native sign-in successful!');
        debugPrint('✅ [AUTH] User: ${_auth.currentUser?.email}');
        if (!mounted) return;
        showSuccessSnackBar(context, 'Connecté avec Google');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ [AUTH] FirebaseAuthException caught");
      debugPrint("❌ [AUTH] Code: ${e.code}");
      debugPrint("❌ [AUTH] Message: ${e.message}");
      debugPrint("❌ [AUTH] Plugin: ${e.plugin}");
      debugPrint("❌ [AUTH] Stack: ${e.stackTrace}");
      
      if (!mounted) return;
      String msg = "Erreur Google";
      if (e.code == 'popup-closed-by-user') {
        msg = "Connexion annulée";
        debugPrint("ℹ️ [AUTH] User closed the popup");
      } else if (e.code == 'unauthorized-domain') {
        msg = "Domaine non autorisé dans Firebase Console";
        debugPrint("⚠️ [AUTH] DOMAIN NOT AUTHORIZED!");
        debugPrint("⚠️ [AUTH] Add this domain in Firebase Console → Authentication → Authorized domains");
      } else if (e.code == 'operation-not-allowed') {
        msg = "Google Sign-In non activé";
        debugPrint("⚠️ [AUTH] GOOGLE SIGN-IN NOT ENABLED!");
        debugPrint("⚠️ [AUTH] Enable it in Firebase Console → Authentication → Sign-in method");
      } else {
        msg = "Erreur : ${e.message ?? e.code}";
      }
      showErrorSnackBar(context, msg);
    } catch (e) {
      debugPrint("❌ [AUTH] Unexpected error");
      debugPrint("❌ [AUTH] Type: ${e.runtimeType}");
      debugPrint("❌ [AUTH] Details: $e");
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur lors de la connexion : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('🔵 [AUTH] Sign-in flow completed');
      debugPrint('🔵 [AUTH] ========================================');
    }
  }

  Future<void> _onAppleSignIn() async {
    if (_isLoading) return;
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      showErrorSnackBar(context, 'Connexion Apple disponible sur iOS/macOS.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (appleCredential.identityToken == null) {
        throw Exception('Identité Apple non reçue');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      await _auth.signInWithCredential(oauthCredential);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Connecté avec Apple');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message ?? 'Erreur Apple: ${e.code}');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur Apple: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onEmailAuth() async {
    if (_isLoading) return;
    if (!(_formKeyAuth.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      if (_authMode == AuthMode.login) {
        await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        if (!mounted) return;
        showSuccessSnackBar(context, 'Connexion réussie');
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (!mounted) return;
        showSuccessSnackBar(context, 'Compte créé');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message ?? 'Erreur: ${e.code}');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onLogout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Déconnecté');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur déconnexion: $e');
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      showErrorSnackBar(context, 'Utilisateur non connecté');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'pseudo': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'postalCode': _cpCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'accountType': _accountType,
        'language': _language,
        'theme': _theme,
        'notifNearby': _notifNearby,
        'notifFavorites': _notifFavorites,
        'notifAcceptOffer': _notifAcceptOffer,
        'notifSystem': _notifSystem,
        'favoriteCategories': _favoriteCategories.map((key, value) => 
          MapEntry(key, value)),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _isEditingProfile = false);
      showSuccessSnackBar(context, 'Profil mis à jour.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur Firestore: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur lors de la sauvegarde: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteOffer(String offerId, String offerTitle) async {
    final user = _auth.currentUser;
    if (user == null) {
      showErrorSnackBar(context, 'Utilisateur non connecté');
      return;
    }

    // Vérifier que l'utilisateur est bien le propriétaire
    try {
      final offerDoc = await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .get();

      if (!offerDoc.exists) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Annonce introuvable');
        return;
      }

      final offerData = offerDoc.data();
      final ownerId = offerData?['ownerId'] ?? offerData?['userId'];
      
      if (ownerId != user.uid) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Vous n\'êtes pas autorisé à supprimer cette annonce');
        return;
      }

      // Confirmer la suppression
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Confirmer la suppression'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Êtes-vous sûr de vouloir supprimer cette annonce ?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  offerTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cette action est irréversible.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Supprimer l'annonce
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .delete();

      if (!mounted) return;
      showSuccessSnackBar(context, 'Annonce supprimée avec succès');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur Firestore: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur lors de la sauvegarde: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Supprimer le compte'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette action est irréversible et entraînera :',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('• Suppression de toutes vos données'),
            const Text('• Suppression de vos annonces'),
            const Text('• Perte de votre historique'),
            const Text('• Déconnexion immédiate'),
            const SizedBox(height: 16),
            Text(
              'Êtes-vous sûr(e) de vouloir continuer ?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      // Suppression des données Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Suppression du compte Firebase Auth
      await user.delete();

      if (!mounted) return;
      showSuccessSnackBar(context, 'Compte supprimé avec succès');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'requires-recent-login') {
        showErrorSnackBar(
          context,
          'Pour votre sécurité, reconnectez-vous avant de supprimer votre compte.',
        );
      } else {
        showErrorSnackBar(context, 'Erreur Auth: ${e.message ?? e.code}');
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur Firestore: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur lors de la suppression: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onForgotPassword() async {
    final email = _emailCtrl.text.trim();
    
    if (email.isEmpty || !email.contains('@')) {
      showErrorSnackBar(context, 'Veuillez saisir un e-mail valide');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Email de réinitialisation envoyé à $email',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Aucun compte associé à cet e-mail';
          break;
        case 'invalid-email':
          message = 'Format d\'e-mail invalide';
          break;
        default:
          message = 'Erreur: ${e.message ?? e.code}';
      }
      showErrorSnackBar(context, message);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur: $e');
    }
  }

  Future<void> _downloadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      showErrorSnackBar(context, 'Utilisateur non connecté');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Aucune donnée trouvée');
        return;
      }

      final data = doc.data() ?? {};
      final jsonData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': user.metadata.creationTime?.toIso8601String(),
        'lastSignIn': user.metadata.lastSignInTime?.toIso8601String(),
        ...data,
      };

      // Convert to pretty JSON string
      const encoder = JsonEncoder.withIndent('  ');
      final prettyJson = encoder.convert(jsonData);

      if (!mounted) return;
      
      // Show dialog with data
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Mes données'),
          content: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                prettyJson,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      
      showSuccessSnackBar(context, 'Données récupérées');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isLoggedIn = user != null;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text(
              'Mon compte ilipresto',
              style: kPrestoAppBarTitleStyle,
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: Container(
            color: colorScheme.surface,
            child: SafeArea(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: false,
                thickness: 6,
                radius: const Radius.circular(8),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: isLoggedIn
                      ? _buildProfileContent(colorScheme, isDark, user)
                      : _buildAuthContent(colorScheme, isDark),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthContent(ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue sur Presto',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Connectez-vous ou créez un compte pour publier et accepter des offres autour de vous.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),

        // Switch Connexion / Inscription
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest
                .withValues(alpha: isDark ? 0.3 : 1),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _authMode = AuthMode.login),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _authMode == AuthMode.login
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Connexion',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _authMode == AuthMode.login
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _authMode = AuthMode.signup),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _authMode == AuthMode.signup
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Inscription',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _authMode == AuthMode.signup
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Boutons Google / Apple
        _buildSocialButton(
          icon: Icons.g_mobiledata,
          label: _authMode == AuthMode.login
              ? 'Se connecter avec Google'
              : "S'inscrire avec Google",
          onTap: () async => _onGoogleSignIn(),
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 8),
        _buildSocialButton(
          icon: Icons.apple,
          label: _authMode == AuthMode.login
              ? 'Se connecter avec Apple'
              : "S'inscrire avec Apple",
          onTap: () async => _onAppleSignIn(),
          colorScheme: colorScheme,
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child:
                    Divider(color: colorScheme.outline.withValues(alpha: 0.4))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('ou avec e-mail'),
            ),
            Expanded(
                child:
                    Divider(color: colorScheme.outline.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 8),

        // Formulaire Email
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKeyAuth,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un e-mail';
                      }
                      if (!value.contains('@')) {
                        return 'Format e-mail invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un mot de passe';
                      }
                      if (value.length < 6) {
                        return 'Minimum 6 caractères';
                      }
                      return null;
                    },
                  ),
                  if (_authMode == AuthMode.signup) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordConfirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (_authMode == AuthMode.signup) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez confirmer le mot de passe';
                          }
                          if (value != _passwordCtrl.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Bouton email
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : () async => _onEmailAuth(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _authMode == AuthMode.login
                            ? 'Se connecter'
                            : 'Créer mon compte',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  if (_authMode == AuthMode.login) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _onForgotPassword,
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
        _buildPrestoPromoCard(colorScheme),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Future<void> Function() onTap,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : () async => onTap(),
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildPrestoPromoCard(ColorScheme colorScheme) {
    return Card(
      color: colorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.bolt, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Besoin d'un jardinier tout de suite ? Publiez votre offre : ils sont des dizaines autour de vous, prêts à accepter le job !",
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(ColorScheme colorScheme, bool isDark, User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header profil
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(Icons.person, size: 32, color: colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameCtrl.text.isEmpty
                        ? 'Mon profil Presto'
                        : _nameCtrl.text,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.verified,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Compte non vérifié',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async => _onLogout(),
              icon: Icon(Icons.logout, color: colorScheme.error),
              tooltip: 'Déconnexion',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Section Mon Profil
        _buildMainSectionCard(
          title: '👤 Mon profil',
          colorScheme: colorScheme,
          child: Form(
            key: _formKeyProfile,
            child: Column(
              children: [
                  TextFormField(
                    controller: _nameCtrl,
                    enabled: _isEditingProfile,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityCtrl,
                    enabled: _isEditingProfile,
                    decoration: const InputDecoration(
                      labelText: 'Commune',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cpCtrl,
                    enabled: _isEditingProfile,
                    decoration: const InputDecoration(
                      labelText: 'C/P',
                      prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  PhoneInputFieldCompact(
                    controller: _phoneCtrl,
                    enabled: _isEditingProfile,
                    labelText: 'Téléphone',
                    hintText: '612345678',
                    onCountryCodeChanged: (code) {
                      debugPrint('Code choisi: $code');
                    },
                    onPhoneChanged: (phone) {
                      debugPrint('Téléphone saisi: $phone');
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    enabled: _isEditingProfile,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyledDropdown<String>(
                          value: _accountType,
                          labelText: 'Type de compte',
                          prefixIcon: Icons.badge_outlined,
                          enabled: _isEditingProfile,
                          items: const [
                            DropdownMenuItem(
                              value: 'Particulier',
                              child: Text('Particulier'),
                            ),
                            DropdownMenuItem(
                              value: 'Pro',
                              child: Text('Pro'),
                            ),
                            DropdownMenuItem(
                              value: 'Micro-Entreprise',
                              child: Text('Micro-Entreprise'),
                            ),
                          ],
                          onChanged: _isEditingProfile ? (value) {
                            if (value != null) {
                              setState(() {
                                _accountType = value;
                              });
                            }
                          } : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _isEditingProfile
                        ? FilledButton.tonalIcon(
                            onPressed: _isLoading ? null : () async {
                              if (_formKeyProfile.currentState?.validate() ?? false) {
                                await _saveProfile();
                              }
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Enregistrer mon profil'),
                          )
                        : FilledButton.tonalIcon(
                            onPressed: () {
                              setState(() => _isEditingProfile = true);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Modifier mon profil'),
                          ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Section Mes Messages
        _buildMainSectionCard(
          title: '💬 Mes messages',
          colorScheme: colorScheme,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.inbox_outlined, color: colorScheme.primary),
                title: const Text('Boîte de réception'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('3', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                onTap: () {
                  // TODO: Navigation vers les messages
                  showSuccessSnackBar(context, 'Fonctionnalité à venir');
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: Icon(Icons.send_outlined, color: colorScheme.primary),
                title: const Text('Messages envoyés'),
                onTap: () {
                  // TODO: Navigation vers messages envoyés
                  showSuccessSnackBar(context, 'Fonctionnalité à venir');
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section Mes Annonces
        _buildMainSectionCard(
          title: '📢 Mes annonces publiées',
          colorScheme: colorScheme,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('offers')
                .where('ownerId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, 
                        size: 48, 
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Erreur lors du chargement',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                );
              }

              final offers = snapshot.data?.docs ?? [];

              if (offers.isEmpty) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 64,
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune annonce publiée',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Créez votre première annonce pour trouver des prestataires',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                      title: const Text('Créer une nouvelle annonce'),
                      onTap: () {
                        // TODO: Navigation vers création d'annonce
                        showSuccessSnackBar(context, 'Fonctionnalité à venir');
                      },
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: offers.length,
                    separatorBuilder: (context, index) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      final data = offer.data() as Map<String, dynamic>;
                      final offerId = offer.id;
                      final title = data['title'] ?? 'Sans titre';
                      final category = data['category'] ?? '';
                      final budget = data['budget'];
                      final createdAt = data['createdAt'] as Timestamp?;
                      final dateStr = createdAt != null
                          ? _formatDate(createdAt.toDate())
                          : '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.article,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (category.isNotEmpty)
                              Text(
                                category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                ),
                              ),
                            if (budget != null)
                              Text(
                                '${budget}€',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: colorScheme.error),
                          tooltip: 'Supprimer',
                          onPressed: () => _deleteOffer(offerId, title),
                        ),
                        onTap: () {
                          // TODO: Navigation vers détail de l'annonce
                          showSuccessSnackBar(context, 'Détail de l\'annonce à venir');
                        },
                      );
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                    title: const Text('Créer une nouvelle annonce'),
                    onTap: () {
                      // TODO: Navigation vers création d'annonce
                      showSuccessSnackBar(context, 'Fonctionnalité à venir');
                    },
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Section Catégories Favorites
        _buildMainSectionCard(
          title: '⭐ Mes catégories favorites',
          colorScheme: colorScheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_favoriteCategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Aucune catégorie favorite sélectionnée',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._favoriteCategories.entries.map((entry) {
                        final category = entry.key;
                        final subcategories = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close,
                                        size: 20, color: colorScheme.error),
                                    onPressed: () {
                                      setState(() {
                                        _favoriteCategories.remove(category);
                                      });
                                    },
                                    tooltip: 'Supprimer',
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...subcategories.map(
                                    (sub) => Chip(
                                      label: Text(sub,
                                          style: const TextStyle(fontSize: 12)),
                                      onDeleted: () {
                                        setState(() {
                                          _favoriteCategories[category]
                                              ?.remove(sub);
                                          if (_favoriteCategories[category]
                                                  ?.isEmpty ??
                                              false) {
                                            _favoriteCategories.remove(category);
                                          }
                                        });
                                      },
                                      backgroundColor: colorScheme.primaryContainer
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              const Divider(height: 0),
              ListTile(
                leading: Icon(Icons.add, color: colorScheme.primary),
                title: const Text('Ajouter une catégorie'),
                onTap: _showAddCategoryDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Préférences (reste comme avant)
        _buildSectionTitle('Préférences'),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSwitchRow(
                  title: 'Offres proches de moi',
                  subtitle:
                      'Recevoir les nouvelles annonces autour de ma position.',
                  value: _notifNearby,
                  onChanged: (v) => setState(() => _notifNearby = v),
                ),
                const Divider(),
                _buildSwitchRow(
                  title: 'Catégories favorites',
                  subtitle:
                      'Être alerté quand une annonce correspond à mes favoris.',
                  value: _notifFavorites,
                  onChanged: (v) => setState(() => _notifFavorites = v),
                ),
                const Divider(),
                _buildSwitchRow(
                  title: 'Quand on accepte mon offre',
                  subtitle:
                      'Notification dès qu\'un prestataire ou un client accepte.',
                  value: _notifAcceptOffer,
                  onChanged: (v) => setState(() => _notifAcceptOffer = v),
                ),
                const Divider(),
                _buildSwitchRow(
                  title: 'Infos système & sécurité',
                  subtitle: 'Mises à jour importantes de Presto.',
                  value: _notifSystem,
                  onChanged: (v) => setState(() => _notifSystem = v),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Langue & thème
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStyledDropdown<String>(
                  value: _language,
                  labelText: 'Langue',
                  prefixIcon: Icons.language,
                  items: const [
                    DropdownMenuItem(
                      value: 'Français',
                      child: Text('Français'),
                    ),
                    DropdownMenuItem(
                      value: 'Créole',
                      child: Text('Créole'),
                    ),
                    DropdownMenuItem(
                      value: 'Anglais',
                      child: Text('Anglais'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildStyledDropdown<String>(
                  value: _theme,
                  labelText: 'Thème',
                  prefixIcon: Icons.brightness_6_outlined,
                  items: const [
                    DropdownMenuItem(
                      value: 'Système',
                      child: Text('Automatique (système)'),
                    ),
                    DropdownMenuItem(
                      value: 'Clair',
                      child: Text('Clair'),
                    ),
                    DropdownMenuItem(
                      value: 'Sombre',
                      child: Text('Sombre'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _theme = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Sécurité & aide
        _buildSectionTitle('Sécurité & aide'),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset_outlined),
                title: const Text('Changer mon mot de passe'),
                onTap: _onForgotPassword,
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Télécharger mes données'),
                onTap: _downloadUserData,
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('FAQ & support'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalInfoPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined,
                    color: colorScheme.error),
                title: Text(
                  'Supprimer mon compte',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: _confirmDeleteAccount,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return "À l'instant";
        }
        return 'Il y a ${diff.inMinutes} min';
      }
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'Il y a $weeks semaine${weeks > 1 ? 's' : ''}';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return 'Il y a $months mois';
    } else {
      final years = (diff.inDays / 365).floor();
      return 'Il y a $years an${years > 1 ? 's' : ''}';
    }
  }

  Widget _buildMainSectionCard({
    required String title,
    required ColorScheme colorScheme,
    required Widget child,
  }) {
    return Card(
      elevation: 3,
      shadowColor: colorScheme.primary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  /// Widget dropdown avec angles arrondis
  Widget _buildStyledDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    String? labelText,
    IconData? prefixIcon,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
      items: items,
      onChanged: enabled ? onChanged : null,
      menuMaxHeight: 250,
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter une catégorie'),
        content: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ..._allCategories.entries.map((entry) {
                final category = entry.key;
                final allSubs = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ...allSubs.map((sub) {
                      final isFavored =
                          _favoriteCategories[category]?.contains(sub) ?? false;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(sub, style: const TextStyle(fontSize: 13)),
                        value: isFavored,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              if (!_favoriteCategories.containsKey(category)) {
                                _favoriteCategories[category] = [];
                              }
                              _favoriteCategories[category]!.add(sub);
                            } else {
                              _favoriteCategories[category]?.remove(sub);
                              if ((_favoriteCategories[category]?.length ??
                                      0) ==
                                  0) {
                                _favoriteCategories.remove(category);
                              }
                            }
                          });
                        },
                      );
                    }),
                  ],
                );
              }),
            ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
