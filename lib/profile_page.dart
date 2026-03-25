import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'services/email_action_service.dart';
import 'utils/friendly_snackbar.dart';
import 'constants.dart';
import 'widgets/phone_input_field.dart';

enum AuthMode { login, signup }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AuthMode _authMode = AuthMode.login;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;
  bool _isLoading = false;

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

  bool get _isAppleSignInSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String get _authHeadline => _authMode == AuthMode.login
      ? 'Bon retour sur Presto'
      : 'Bienvenue sur Presto';

  String get _authSubtitle => _authMode == AuthMode.login
      ? 'Connectez-vous pour retrouver vos offres, vos messages et vos préférences.'
      : 'Créez votre compte pour publier une offre, accepter des missions et discuter avec les prestataires autour de vous.';

  bool _notifNearby = true;
  bool _notifFavorites = true;
  bool _notifAcceptOffer = true;
  bool _notifSystem = true;
  bool _marketingEmailsEnabled = false;
  bool _quietHoursEnabled = true;

  String _accountType = 'Particulier';
  String _language = 'Français';
  String _theme = 'Système';
  String _savedSearchEmailMode = 'daily';
  String _messagingEmailMode = 'immediate';
  String _listingEmailMode = 'immediate';
  String _timezone = 'America/Guadeloupe';
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '08:00';

  static const List<String> _supportedTimezones = [
    'America/Guadeloupe',
    'America/Martinique',
    'America/Guyana',
    'Europe/Paris',
    'UTC',
  ];

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
      if (user != null) {
        _loadNotificationPreferences(user.uid);
      }
    });

    // Sur Web, vérifie si l'utilisateur revient d'un redirect Google Sign-In
    if (kIsWeb) {
      _checkGoogleRedirectResult();
    }
  }

  Future<void> _checkGoogleRedirectResult() async {
    try {
      final result = await _auth.getRedirectResult();
      if (result.user != null) {
        if (!mounted) return;
        showSuccessSnackBar(context, "Connecté avec Google");
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = "Erreur Google";
      if (e.code == 'unauthorized-domain') {
        msg =
            "Domaine non autorisé. Ajoutez ce domaine dans Firebase Console → Authentication → Authorized domains.";
      } else if (e.code == 'operation-not-allowed') {
        msg =
            "Google Sign-In non activé. Activez-le dans Firebase Console → Authentication → Sign-in method.";
      } else if (e.code != 'invalid-credential' && e.code != 'no-auth-event') {
        msg = "Erreur Google : ${e.message ?? e.code}";
        showErrorSnackBar(context, msg);
      }
    } catch (e) {
      debugPrint('[Google Redirect] Error checking result: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _cpCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationPreferences(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('notification_preferences')
          .doc(userId)
          .get();
      final data = doc.data();
      if (data == null || !mounted) return;

      final emailPrefs =
          (data['email'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final savedSearches =
          (emailPrefs['saved_searches'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final messaging =
          (emailPrefs['messaging'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        final listings =
          (emailPrefs['listings'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final favorites =
          (emailPrefs['favorites'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      final support =
          (emailPrefs['support'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        final marketing =
          (emailPrefs['marketing'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        final quietHours =
          (data['quiet_hours'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      setState(() {
        final savedSearchMode = (savedSearches['mode'] ?? 'daily').toString();
        final messagingMode = (messaging['mode'] ?? 'immediate').toString();
        final listingMode = (listings['mode'] ?? 'immediate').toString();

        _savedSearchEmailMode = savedSearchMode == 'instant' ? 'daily' : savedSearchMode;
        _messagingEmailMode = messagingMode;
        _listingEmailMode = listingMode;

        _notifNearby = _savedSearchEmailMode != 'off';
        _notifAcceptOffer = _messagingEmailMode != 'off';
        _notifFavorites = favorites['enabled'] != false;
        _notifSystem = support['enabled'] != false;
        _marketingEmailsEnabled = marketing['enabled'] == true;
        _quietHoursEnabled = quietHours['enabled'] != false;
        _timezone = (data['timezone'] ?? 'America/Guadeloupe').toString();
        _quietHoursStart = (quietHours['start_local'] ?? '22:00').toString();
        _quietHoursEnd = (quietHours['end_local'] ?? '08:00').toString();

        final locale = (data['locale'] ?? 'fr').toString();
        if (locale == 'en') {
          _language = 'Anglais';
        } else if (_language == 'Anglais') {
          _language = 'Français';
        }
      });
    } catch (_) {
      // best effort
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      provider.addScope('email');
      provider.addScope('profile');

      if (kIsWeb) {
        try {
          await _auth.signInWithPopup(provider);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Connecté avec Google');
        } catch (popupError) {
          debugPrint("POPUP BLOCKED -> Fallback to redirect: $popupError");
          // Fallback redirect (ex: popup bloquée)
          await _auth.signInWithRedirect(provider);
          // Le navigateur va rediriger, on ne continue pas l'exécution
          return;
        }
      } else {
        await _auth.signInWithProvider(provider);
        if (!mounted) return;
        showSuccessSnackBar(context, 'Connecté avec Google');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("GOOGLE AUTH FAIL -> code=${e.code} message=${e.message}");
      if (!mounted) return;
      String msg = "Erreur Google";
      if (e.code == 'popup-closed-by-user') {
        msg = "Connexion annulée";
      } else if (e.code == 'unauthorized-domain') {
        msg = "Domaine non autorisé dans Firebase Console";
      } else {
        msg = "Erreur : ${e.message ?? e.code}";
      }
      showErrorSnackBar(context, msg);
    } catch (e) {
      debugPrint("GOOGLE AUTH FAIL -> $e");
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur lors de la connexion : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onAppleSignIn() async {
    if (_isLoading) return;
    if (!_isAppleSignInSupported) {
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
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential.user != null) {
          await EmailActionService.requestEmailVerificationEmail();
        }
        if (!mounted) return;
        showSuccessSnackBar(context, 'Compte créé. Vérifiez votre e-mail.');
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

  Future<void> _saveProfile() async {
    if (!(_formKeyProfile.currentState?.validate() ?? false)) return;

    final user = _auth.currentUser;
    if (user == null) {
      showErrorSnackBar(context, 'Connecte-toi pour enregistrer ton profil.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final displayName = _nameCtrl.text.trim();
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pseudo': displayName,
        'city': _cityCtrl.text.trim(),
        'postalCode': _cpCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'accountType': _accountType,
        'preferences': {
          'notifNearby': _savedSearchEmailMode != 'off',
          'notifFavorites': _notifFavorites,
          'notifAcceptOffer': _messagingEmailMode != 'off',
          'notifSystem': _notifSystem,
          'savedSearchMode': _savedSearchEmailMode,
          'messagingMode': _messagingEmailMode,
          'listingMode': _listingEmailMode,
          'marketingEmailsEnabled': _marketingEmailsEnabled,
          'quietHoursEnabled': _quietHoursEnabled,
          'timezone': _timezone,
          'language': _language,
          'theme': _theme,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('notification_preferences')
          .doc(user.uid)
          .set({
        'user_id': user.uid,
        'locale': _language == 'Anglais' ? 'en' : 'fr',
        'timezone': _timezone,
        'quiet_hours': {
          'enabled': _quietHoursEnabled,
          'start_local': _quietHoursStart,
          'end_local': _quietHoursEnd,
        },
        'email': {
          'account': {'enabled': true},
          'messaging': {'mode': _messagingEmailMode},
          'listings': {'mode': _listingEmailMode},
          'saved_searches': {'mode': _savedSearchEmailMode},
          'favorites': {'enabled': _notifFavorites},
          'support': {'enabled': _notifSystem},
          'marketing': {
            'enabled': _marketingEmailsEnabled,
            'frequency_cap_per_week': 2,
          },
        },
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      showSuccessSnackBar(context, 'Profil mis à jour.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Impossible d\'enregistrer le profil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateTicketNumber() {
    final now = DateTime.now();
    return 'SUP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';
  }

  Future<String> _createSupportTicket({
    required String subject,
    required String description,
    required String category,
    String priority = 'normal',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté');
    }

    final ticketNumber = _generateTicketNumber();
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{
      'user_id': user.uid,
      'ticket_number': ticketNumber,
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority,
      'status': 'open',
      'last_reply_from': 'user',
      'created_at': now,
      'updated_at': now,
      'request_source': 'profile_page',
      'requester_email': user.email,
    };

    await FirebaseFirestore.instance
        .collection('support_tickets')
        .add(payload);

    return ticketNumber;
  }

  Future<void> _openSupportTicketComposer() async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contacter le support'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: subjectCtrl,
                decoration: const InputDecoration(labelText: 'Sujet'),
                validator: (value) {
                  if ((value ?? '').trim().length < 5) {
                    return 'Décris brièvement ta demande';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: messageCtrl,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Message'),
                validator: (value) {
                  if ((value ?? '').trim().length < 20) {
                    return 'Ajoute quelques détails pour aider le support';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      subjectCtrl.dispose();
      messageCtrl.dispose();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ticketNumber = await _createSupportTicket(
        subject: subjectCtrl.text.trim(),
        description: messageCtrl.text.trim(),
        category: 'general_support',
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Demande envoyée. Référence: $ticketNumber');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Impossible d’envoyer la demande: $e');
    } finally {
      subjectCtrl.dispose();
      messageCtrl.dispose();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onChangePasswordTapped() async {
    final user = _auth.currentUser;
    final targetEmail = (_auth.currentUser?.email ?? _emailCtrl.text).trim();
    if (targetEmail.isEmpty) {
      showErrorSnackBar(context, 'Aucun e-mail disponible pour le reset.');
      return;
    }

    final hasPasswordProvider =
        user?.providerData.any((provider) => provider.providerId == 'password') ??
            false;

    if (user == null || !hasPasswordProvider) {
      try {
        await EmailActionService.requestPasswordResetEmail(targetEmail);
        if (!mounted) return;
        showSuccessSnackBar(
          context,
          'E-mail de réinitialisation envoyé à $targetEmail',
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        showErrorSnackBar(context, e.message ?? 'Erreur de réinitialisation.');
      }
      return;
    }

    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer mon mot de passe'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Saisis ton mot de passe actuel';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (value) {
                  final password = (value ?? '').trim();
                  if (password.length < 6) {
                    return '6 caractères minimum';
                  }
                  if (password == currentPasswordCtrl.text.trim()) {
                    return 'Choisis un mot de passe différent';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                validator: (value) {
                  if ((value ?? '').trim() != newPasswordCtrl.text.trim()) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      currentPasswordCtrl.dispose();
      newPasswordCtrl.dispose();
      confirmPasswordCtrl.dispose();
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: targetEmail,
        password: currentPasswordCtrl.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPasswordCtrl.text.trim());
      await EmailActionService.reportPasswordChanged();
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Mot de passe mis à jour.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message ?? 'Erreur de changement de mot de passe.');
    } finally {
      currentPasswordCtrl.dispose();
      newPasswordCtrl.dispose();
      confirmPasswordCtrl.dispose();
    }
  }

  Future<void> _onDownloadDataTapped() async {
    setState(() => _isLoading = true);
    try {
      final ticketNumber = await _createSupportTicket(
        subject: 'Demande d’export de données',
        description: 'Je souhaite recevoir un export de mes données personnelles et de mon historique d’activité lié à mon compte PRESTO.',
        category: 'data_export',
        priority: 'high',
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Demande d’export enregistrée. Référence: $ticketNumber');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Impossible de créer la demande d’export: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSupportTapped() async {
    await _openSupportTicketComposer();
  }

  Future<void> _onDeleteAccountTapped() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Cette action est irréversible. Veux-tu vraiment supprimer ton compte ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final ticketNumber = await _createSupportTicket(
        subject: 'Demande de suppression de compte',
        description: 'Je confirme demander la suppression de mon compte PRESTO et l’effacement associé de mes données, sous réserve des obligations légales de conservation.',
        category: 'account_deletion',
        priority: 'high',
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Demande de suppression enregistrée. Référence: $ticketNumber');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Impossible de créer la demande de suppression: $e');
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

  Future<void> _onForgotPassword() async {
    if (_isLoading) return;

    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      showErrorSnackBar(context,
          'Saisis ton e-mail pour recevoir un lien de réinitialisation.');
      return;
    }

    if (!email.contains('@')) {
      showErrorSnackBar(context, 'Renseigne une adresse e-mail valide.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await EmailActionService.requestPasswordResetEmail(email);
      if (!mounted) return;
      showSuccessSnackBar(
          context, 'Lien de réinitialisation envoyé par e-mail.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context,
          e.message ?? 'Impossible d\'envoyer l\'e-mail de réinitialisation.');
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
          appBar: AppBar(
            title: const Text(
              'Mon profil',
              style: kPrestoAppBarTitleStyle,
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: isLoggedIn
                ? BoxDecoration(color: colorScheme.surface)
                : const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF4EC),
                        Color(0xFFEAF2FF),
                        Colors.white,
                      ],
                    ),
                  ),
            child: Stack(
              children: [
                if (!isLoggedIn)
                  Positioned(
                    top: -70,
                    left: -50,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF6600).withOpacity(0.10),
                      ),
                    ),
                  ),
                if (!isLoggedIn)
                  Positioned(
                    top: 120,
                    right: -60,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A73E8).withOpacity(0.10),
                      ),
                    ),
                  ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, isLoggedIn ? 28 : 72),
                    child: isLoggedIn
                        ? _buildProfileContent(colorScheme, isDark, user)
                        : _buildAuthContent(colorScheme, isDark),
                  ),
                ),
              ],
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
          _authHeadline,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _authSubtitle,
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

        _buildSocialButton(
          icon: const _GoogleBrandLogo(size: 18),
          label: 'Continuer avec Google',
          onTap: () async => _onGoogleSignIn(),
          colorScheme: colorScheme,
          forceWhiteBackground: true,
        ),
        if (_isAppleSignInSupported) ...[
          const SizedBox(height: 8),
          _buildSocialButton(
            icon: const Icon(Icons.apple),
            label: 'Continuer avec Apple',
            onTap: () async => _onAppleSignIn(),
            colorScheme: colorScheme,
          ),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child:
                    Divider(color: colorScheme.outline.withValues(alpha: 0.4))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('ou continuez avec e-mail'),
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
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
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
                    autofillHints: _authMode == AuthMode.login
                        ? const [AutofillHints.password]
                        : const [AutofillHints.newPassword],
                    textInputAction: _authMode == AuthMode.signup
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (_authMode == AuthMode.login) {
                        _onEmailAuth();
                      }
                    },
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
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onEmailAuth(),
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
                        _isLoading
                            ? 'Chargement...'
                            : _authMode == AuthMode.login
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
                        onPressed:
                            _isLoading ? null : () => _onForgotPassword(),
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
    required Widget icon,
    required String label,
    required Future<void> Function() onTap,
    required ColorScheme colorScheme,
    bool forceWhiteBackground = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : () async => onTap(),
        icon: icon,
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: forceWhiteBackground ? Colors.white : null,
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

        // Infos personnelles
        _buildSectionTitle('Informations personnelles'),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKeyProfile,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Commune',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cpCtrl,
                    decoration: const InputDecoration(
                      labelText: 'C/P',
                      prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  PhoneInputFieldCompact(
                    controller: _phoneCtrl,
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
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _accountType = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Préférences
        _buildSectionTitle('Préférences'),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStyledDropdown<String>(
                  value: _savedSearchEmailMode,
                  labelText: 'Alertes recherches sauvegardées',
                  prefixIcon: Icons.search_outlined,
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Quotidien')),
                    DropdownMenuItem(value: 'weekly', child: Text('Hebdomadaire')),
                    DropdownMenuItem(value: 'off', child: Text('Désactivé')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _savedSearchEmailMode = value;
                      _notifNearby = value != 'off';
                    });
                  },
                ),
                const Divider(),
                _buildStyledDropdown<String>(
                  value: _messagingEmailMode,
                  labelText: 'Messages et leads',
                  prefixIcon: Icons.forum_outlined,
                  items: const [
                    DropdownMenuItem(value: 'immediate', child: Text('Immédiat')),
                    DropdownMenuItem(value: 'digest_daily', child: Text('Digest quotidien')),
                    DropdownMenuItem(value: 'digest_weekly', child: Text('Digest hebdomadaire')),
                    DropdownMenuItem(value: 'off', child: Text('Désactivé')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _messagingEmailMode = value;
                      _notifAcceptOffer = value != 'off';
                    });
                  },
                ),
                const Divider(),
                _buildStyledDropdown<String>(
                  value: _listingEmailMode,
                  labelText: 'Suivi de mes annonces',
                  prefixIcon: Icons.campaign_outlined,
                  items: const [
                    DropdownMenuItem(value: 'immediate', child: Text('Immédiat')),
                    DropdownMenuItem(value: 'digest_daily', child: Text('Digest quotidien')),
                    DropdownMenuItem(value: 'digest_weekly', child: Text('Digest hebdomadaire')),
                    DropdownMenuItem(value: 'off', child: Text('Désactivé')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _listingEmailMode = value);
                  },
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
                  title: 'Infos système & sécurité',
                  subtitle: 'Mises à jour importantes de Presto.',
                  value: _notifSystem,
                  onChanged: (v) => setState(() => _notifSystem = v),
                ),
                const Divider(),
                _buildSwitchRow(
                  title: 'Emails marketing',
                  subtitle: 'Recevoir conseils, nouveautés et sélection PRESTO.',
                  value: _marketingEmailsEnabled,
                  onChanged: (v) => setState(() => _marketingEmailsEnabled = v),
                ),
                const Divider(),
                _buildSwitchRow(
                  title: 'Quiet hours',
                  subtitle: 'Décaler les emails non urgents hors de la nuit.',
                  value: _quietHoursEnabled,
                  onChanged: (v) => setState(() => _quietHoursEnabled = v),
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
                  value: _timezone,
                  labelText: 'Fuseau horaire',
                  prefixIcon: Icons.schedule_outlined,
                  items: _supportedTimezones
                      .map(
                        (timezone) => DropdownMenuItem(
                          value: timezone,
                          child: Text(timezone),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _timezone = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStyledDropdown<String>(
                        value: _quietHoursStart,
                        labelText: 'Quiet hours début',
                        prefixIcon: Icons.bedtime_outlined,
                        items: const [
                          DropdownMenuItem(value: '20:00', child: Text('20:00')),
                          DropdownMenuItem(value: '21:00', child: Text('21:00')),
                          DropdownMenuItem(value: '22:00', child: Text('22:00')),
                          DropdownMenuItem(value: '23:00', child: Text('23:00')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _quietHoursStart = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStyledDropdown<String>(
                        value: _quietHoursEnd,
                        labelText: 'Quiet hours fin',
                        prefixIcon: Icons.wb_sunny_outlined,
                        items: const [
                          DropdownMenuItem(value: '06:00', child: Text('06:00')),
                          DropdownMenuItem(value: '07:00', child: Text('07:00')),
                          DropdownMenuItem(value: '08:00', child: Text('08:00')),
                          DropdownMenuItem(value: '09:00', child: Text('09:00')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _quietHoursEnd = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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

        const SizedBox(height: 16),

        // Catégories favorites
        _buildSectionTitle('Mes catégories favorites'),
        Card(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_favoriteCategories.isEmpty)
                  Text(
                    'Aucune catégorie favori sélectionnée',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddCategoryDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une catégorie'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

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
                onTap: _onChangePasswordTapped,
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Télécharger mes données'),
                onTap: _onDownloadDataTapped,
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('FAQ & support'),
                onTap: _onSupportTapped,
              ),
              const Divider(height: 0),
              ListTile(
                leading: Icon(Icons.delete_forever_outlined,
                    color: colorScheme.error),
                title: Text(
                  'Supprimer mon compte',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: _onDeleteAccountTapped,
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
    required ValueChanged<T?> onChanged,
    String? labelText,
    IconData? prefixIcon,
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
      onChanged: onChanged,
      menuMaxHeight: 250,
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter une catégorie'),
        content: SingleChildScrollView(
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

class _GoogleBrandLogo extends StatelessWidget {
  final double size;

  const _GoogleBrandLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleBrandLogoPainter(),
      ),
    );
  }
}

class _GoogleBrandLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFEA4335); // red
    canvas.drawArc(rect, 3.75, 1.05, false, paint);
    paint.color = const Color(0xFFFBBC05); // yellow
    canvas.drawArc(rect, 4.80, 1.00, false, paint);
    paint.color = const Color(0xFF34A853); // green
    canvas.drawArc(rect, 5.80, 1.00, false, paint);
    paint.color = const Color(0xFF4285F4); // blue
    canvas.drawArc(rect, 0.52, 2.40, false, paint);

    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    final barH = stroke * 0.82;
    final barY = size.height / 2 - barH / 2;
    final barX = size.width * 0.52;
    final barW = size.width * 0.36;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        Radius.circular(barH / 2),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
