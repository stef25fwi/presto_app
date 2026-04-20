// ACTIF_SECONDAIRE: flux auth/profil fallback encore reachable hors parcours compte principal.

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/presto_overlay_theme.dart';
import 'main.dart' show pendingRedirectAuthResult, pendingRedirectAuthError;
import 'pages/pro_profile_page.dart';
import 'services/account_social_auth_actions.dart';
import 'services/city_search.dart';
import 'services/email_action_service.dart';
import 'services/firebase_functions_region.dart';
import 'services/google_auth_service.dart';
import 'services/notification_service.dart';
import 'services/user_profile_bootstrap_service.dart';
import 'services/app_route_parser.dart';
import 'utils/friendly_snackbar.dart';
import 'constants.dart';
import 'widgets/phone_input_field.dart';

enum AuthMode { login, signup }

const kIliPrestoOrange = Color(0xFFFF6600);
const kIliPrestoBlue = Color(0xFF1A73E8);
const kIliPrestoCream = Color(0xFFFFF7F1);
const kIliPrestoSky = Color(0xFFF2F7FF);
const kIliPrestoBorder = Color(0xFFD8E6FB);
const kIliPrestoTextMuted = Color(0xFF6B7280);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AuthMode _authMode = AuthMode.login;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = prestoFirebaseFunctions;
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  bool _isLoading = false;
  bool _isProfileHydrating = false;
  bool _isApplyingProfileData = false;
  String? _activeProfileUid;

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
  String _phoneCountryCode = '+33';
  final Set<String> _dirtyProfileFields = <String>{};

  bool get _isAppleSignInSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String get _authHeadline => _authMode == AuthMode.login
      ? 'Bon retour sur iliprestō'
      : 'Bienvenue sur iliprestō';

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
    _registerProfileFieldListeners();
    if (kIsWeb) {
      _checkFederatedRedirectResult();
    }
    _authSub = _auth.authStateChanges().listen((user) async {
      final email = user?.email;
      if (email != null && email.isNotEmpty && _emailCtrl.text != email) {
        _emailCtrl.text = email;
      }
      if (user != null) {
        if (_activeProfileUid != user.uid) {
          try {
            await UserProfileBootstrapService.ensureUserDocument(
              user: user,
              authMethod: 'session_restore',
            );
          } catch (e) {
            debugPrint('[AuthBootstrap] session restore failed: $e');
          }
          try {
            await EmailActionService.syncCurrentUserEmailVerificationState();
          } catch (_) {
            // Best effort
          }
        }
        _bindProfile(user);
        _loadNotificationPreferences(user.uid);
      } else {
        _unbindProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _cpCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFederatedRedirectResult() async {
    try {
      UserCredential? result = pendingRedirectAuthResult;
      if (result == null && pendingRedirectAuthError == null) {
        result = await _auth.getRedirectResult();
      } else if (pendingRedirectAuthError != null && result == null) {
        final captured = pendingRedirectAuthError;
        if (captured is FirebaseAuthException) throw captured;
        throw captured ?? StateError('OAuth redirect failed');
      }

      if (result?.user != null) {
        final isNew = result!.additionalUserInfo?.isNewUser ?? false;
        final providerId = result.additionalUserInfo?.providerId ??
            result.user!.providerData.firstOrNull?.providerId ??
            '';
        final authMethod = switch (providerId) {
          'facebook.com' => 'facebook',
          'google.com' => 'google',
          _ => 'social',
        };
        final providerLabel = switch (providerId) {
          'facebook.com' => 'Facebook',
          'google.com' => 'Google',
          _ => 'externe',
        };
        try {
          await UserProfileBootstrapService.ensureUserDocument(
            user: result.user!,
            authMethod: authMethod,
            isNewUserHint: isNew,
          );
        } catch (e) {
          debugPrint('[ProfilePage/OAuthRedirect] Bootstrap error: $e');
        }
        if (!mounted) return;
        showSuccessSnackBar(context, 'Connecté avec $providerLabel');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code != 'invalid-credential' && e.code != 'no-auth-event') {
        String msg;
        if (e.code == 'unauthorized-domain') {
          msg = 'Domaine non autorisé dans Firebase Authentication.';
        } else if (e.code == 'operation-not-allowed') {
          msg = 'Fournisseur externe non activé dans Firebase Authentication.';
        } else {
          msg = 'Erreur connexion externe : ${e.message ?? e.code}';
        }
        showErrorSnackBar(context, msg);
      }
    } catch (e) {
      debugPrint('[ProfilePage/OAuthRedirect] Error: $e');
    }
  }

  void _registerProfileFieldListeners() {
    _nameCtrl.addListener(() => _markProfileFieldDirty('name'));
    _cityCtrl.addListener(() {
      _markProfileFieldDirty('city');
      _syncPhoneCountryCodeFromLocationFields();
    });
    _cpCtrl.addListener(() {
      _markProfileFieldDirty('postalCode');
      _syncPhoneCountryCodeFromLocationFields();
    });
    _phoneCtrl.addListener(() => _markProfileFieldDirty('phone'));
    _emailCtrl.addListener(() => _markProfileFieldDirty('email'));
  }

  void _markProfileFieldDirty(String field) {
    if (_isApplyingProfileData) {
      return;
    }
    _dirtyProfileFields.add(field);
  }

  String _countryCodeForDept(String dept) {
    if (dept.startsWith('971')) return '+590';
    if (dept.startsWith('972')) return '+596';
    if (dept.startsWith('973')) return '+594';
    if (dept.startsWith('974')) return '+262';
    if (dept.startsWith('976')) return '+262';
    if (dept.startsWith('987')) return '+689';
    return '+33';
  }

  String? _extractPostalCodeFromLocationValue(String value) {
    final match = RegExp(r'\b(97\d{3}|98\d{3}|\d{5})\b').firstMatch(value);
    return match?.group(1);
  }

  void _syncPhoneCountryCodeFromLocationFields() {
    if (_isApplyingProfileData) {
      return;
    }

    String? dept;
    final postalCode = _cpCtrl.text.trim().isNotEmpty
        ? _cpCtrl.text.trim()
        : (_extractPostalCodeFromLocationValue(_cityCtrl.text) ?? '');

    if (postalCode.isNotEmpty) {
      dept = (postalCode.startsWith('97') || postalCode.startsWith('98'))
          ? postalCode.substring(0, 3)
          : postalCode.substring(0, 2);
    } else {
      final sanitizedCity =
          _cityCtrl.text.replaceAll(RegExp(r'\(.*?\)'), '').trim();
      if (sanitizedCity.length >= 2) {
        final matches = CitySearch.instance.search(sanitizedCity, limit: 1);
        if (matches.isNotEmpty) {
          dept = matches.first.dept;
        }
      }
    }

    final nextCode = _countryCodeForDept(dept ?? '');
    if (nextCode != _phoneCountryCode && mounted) {
      setState(() {
        _phoneCountryCode = nextCode;
      });
    }
  }

  void _bindProfile(User user) {
    if (_activeProfileUid == user.uid && _profileSub != null) {
      return;
    }

    _profileSub?.cancel();
    _activeProfileUid = user.uid;
    _dirtyProfileFields.clear();
    setState(() {
      _isProfileHydrating = true;
    });

    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _applyProfileData(user, snapshot.data());
          _isProfileHydrating = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _applyProfileData(user, null);
          _isProfileHydrating = false;
        });
      },
    );
  }

  void _unbindProfile() {
    _profileSub?.cancel();
    _profileSub = null;
    _activeProfileUid = null;
    _dirtyProfileFields.clear();
    _isApplyingProfileData = true;
    try {
      _nameCtrl.clear();
      _cityCtrl.clear();
      _cpCtrl.clear();
      _phoneCtrl.clear();
      _phoneCountryCode = '+33';
      _emailCtrl.clear();
      _accountType = 'Particulier';
      _favoriteCategories
        ..clear()
        ..addAll({
          'Jardinage': ['Tondeuse', 'Élagage'],
          'Peinture': ['Intérieur'],
        });
    } finally {
      _isApplyingProfileData = false;
    }
    if (mounted) {
      setState(() {
        _isProfileHydrating = false;
      });
    }
  }

  void _applyProfileData(User user, Map<String, dynamic>? data) {
    final profileData = data ?? const <String, dynamic>{};
    final profileName = [
      profileData['pseudo'],
      profileData['displayName'],
      profileData['display_name'],
      profileData['name'],
      user.displayName,
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final profileCity = [
      profileData['city'],
      profileData['location'],
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final profilePostalCode = [
      profileData['postalCode'],
      profileData['cp'],
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final profilePhone = [
      profileData['phone'],
      profileData['phoneNumber'],
      profileData['phone_number'],
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final profileEmail = [
      user.email,
      profileData['email'],
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final profileAccountType =
        (profileData['accountType'] ?? '').toString().trim();
    final profilePhoneCountryCode =
        (profileData['phoneCountryCode'] ?? '').toString().trim();

    _isApplyingProfileData = true;
    try {
      _setControllerText(_nameCtrl, 'name', profileName);
      _setControllerText(_cityCtrl, 'city', profileCity);
      _setControllerText(_cpCtrl, 'postalCode', profilePostalCode);
      _applyProfilePhone(
        profilePhone,
        explicitCountryCode: profilePhoneCountryCode,
      );
      _setControllerText(_emailCtrl, 'email', profileEmail);

      if (!_dirtyProfileFields.contains('accountType') &&
          profileAccountType.isNotEmpty) {
        _accountType = profileAccountType;
      }
    } finally {
      _isApplyingProfileData = false;
    }
  }

  void _applyProfilePhone(
    String rawPhone, {
    String? explicitCountryCode,
  }) {
    if (_dirtyProfileFields.contains('phone') &&
        _phoneCtrl.text.trim().isNotEmpty) {
      return;
    }

    final normalizedExplicitCode = (explicitCountryCode ?? '').trim();
    final knownCodes =
        kPhoneCountryCodes.map((country) => country.code).toList();
    final trimmed = rawPhone.trim();

    if (trimmed.isEmpty) {
      _phoneCountryCode = knownCodes.contains(normalizedExplicitCode)
          ? normalizedExplicitCode
          : '+33';
      _setControllerText(_phoneCtrl, 'phone', '');
      return;
    }

    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    final allDigits = compact.replaceAll(RegExp(r'\D'), '');

    var resolvedCode = normalizedExplicitCode;
    if (resolvedCode.isEmpty || !knownCodes.contains(resolvedCode)) {
      for (final code in knownCodes) {
        if (compact.startsWith(code)) {
          resolvedCode = code;
          break;
        }
      }
    }

    if (resolvedCode.isEmpty || !knownCodes.contains(resolvedCode)) {
      resolvedCode = '+33';
    }

    final codeDigits = resolvedCode.replaceAll(RegExp(r'\D'), '');
    var localDigits = allDigits;
    if (codeDigits.isNotEmpty && allDigits.startsWith(codeDigits)) {
      localDigits = allDigits.substring(codeDigits.length);
    }

    _phoneCountryCode = resolvedCode;
    _setControllerText(
      _phoneCtrl,
      'phone',
      localDigits.isNotEmpty ? localDigits : trimmed,
    );
  }

  String _normalizePhoneForSave(String countryCode, String rawPhone) {
    final codeDigits = countryCode.replaceAll(RegExp(r'\D'), '');
    var phoneDigits = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (phoneDigits.isEmpty) {
      return '';
    }

    if (phoneDigits.startsWith('00')) {
      phoneDigits = phoneDigits.substring(2);
    }

    if (codeDigits.isNotEmpty && phoneDigits.startsWith(codeDigits)) {
      return '+$phoneDigits';
    }

    if (phoneDigits.startsWith('0')) {
      phoneDigits = phoneDigits.substring(1);
    }

    return codeDigits.isEmpty ? phoneDigits : '+$codeDigits$phoneDigits';
  }

  void _setControllerText(
    TextEditingController controller,
    String field,
    String value,
  ) {
    final normalized = value.trim();
    if (_dirtyProfileFields.contains(field) &&
        controller.text.trim().isNotEmpty) {
      return;
    }
    if (controller.text == normalized) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _loadNotificationPreferences(String userId) async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('notification_preferences')
            .doc(userId)
            .get(),
        FirebaseFirestore.instance.collection('users').doc(userId).get(),
      ]);
      final prefsData = results[0].data();
      final userData = results[1].data();
      if (!mounted) return;

      final emailPrefs = (prefsData?['email'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final pushPrefs = (prefsData?['push'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final savedSearches =
          (emailPrefs['saved_searches'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};
      final messaging = (emailPrefs['messaging'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final listings = (emailPrefs['listings'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final favorites = (emailPrefs['favorites'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final support = (emailPrefs['support'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final marketing = (emailPrefs['marketing'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final quietHours = (prefsData?['quiet_hours'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final pushMessaging = (pushPrefs['messaging'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final pushFavorites = (pushPrefs['favorites'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final pushSupport = (pushPrefs['support'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final favoriteCategoryMap =
          (userData?['favoriteCategoryMap'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};

      setState(() {
        final savedSearchMode = (savedSearches['mode'] ?? 'daily').toString();
        final messagingMode = (messaging['mode'] ?? 'immediate').toString();
        final listingMode = (listings['mode'] ?? 'immediate').toString();

        _savedSearchEmailMode =
            savedSearchMode == 'instant' ? 'daily' : savedSearchMode;
        _messagingEmailMode = messagingMode;
        _listingEmailMode = listingMode;

        _notifNearby = _savedSearchEmailMode != 'off';
        _notifAcceptOffer =
            _messagingEmailMode != 'off' && pushMessaging['enabled'] != false;
        _notifFavorites =
            favorites['enabled'] != false && pushFavorites['enabled'] != false;
        _notifSystem =
            support['enabled'] != false && pushSupport['enabled'] != false;
        _marketingEmailsEnabled = marketing['enabled'] == true;
        _quietHoursEnabled = quietHours['enabled'] != false;
        _timezone = (prefsData?['timezone'] ?? 'America/Guadeloupe').toString();
        _quietHoursStart = (quietHours['start_local'] ?? '22:00').toString();
        _quietHoursEnd = (quietHours['end_local'] ?? '08:00').toString();

        _favoriteCategories
          ..clear()
          ..addAll(
            favoriteCategoryMap.map(
              (key, value) => MapEntry(
                key,
                (value as List<dynamic>? ?? const [])
                    .map((entry) => entry.toString())
                    .where((entry) => entry.isNotEmpty)
                    .toList(growable: true),
              ),
            ),
          );

        final locale = (prefsData?['locale'] ?? 'fr').toString();
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

  Future<void> _trackLogin({
    String? authMethod,
    bool isNewUser = false,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'trackUserLogin',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );
      await callable.call<dynamic>({
        'authMethod': authMethod,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'deviceType': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'isNewUser': isNewUser,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (error) {
      debugPrint('[ProfilePage][Tracking] Error: $error');
    }
  }

  String _friendlyEmailAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'user-disabled':
        return 'Ce compte a ete desactive.';
      case 'user-not-found':
        return 'Aucun compte trouve avec cet e-mail.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe deja avec cet e-mail.';
      case 'weak-password':
        return 'Mot de passe trop faible (minimum 6 caracteres).';
      case 'too-many-requests':
        return 'Trop de tentatives. Reessayez dans quelques minutes.';
      case 'network-request-failed':
        return 'Erreur reseau. Verifiez la connexion internet.';
      case 'operation-not-allowed':
        return 'Connexion e-mail non activee dans Firebase Authentication.';
      default:
        return error.message ?? 'Erreur d\'authentification.';
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await AccountSocialAuthActions.signInWithGoogle(
        context: context,
        auth: _auth,
        googleAuthService: _googleAuthService,
        trackLogin: _trackLogin,
      );
    } finally {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        try {
          await EmailActionService.syncCurrentUserEmailVerificationState();
        } catch (_) {
          // Best effort.
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onAppleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await AccountSocialAuthActions.signInWithApple(
        context: context,
        auth: _auth,
        trackLogin: _trackLogin,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onFacebookSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await AccountSocialAuthActions.signInWithFacebook(
        context: context,
        auth: _auth,
        trackLogin: _trackLogin,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onEmailAuth() async {
    if (_isLoading) return;
    if (!(_formKeyAuth.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final password = _passwordCtrl.text;
      bool bootstrapFailed = false;

      if (_authMode == AuthMode.login) {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential.user != null) {
          try {
            await UserProfileBootstrapService.ensureUserDocument(
              user: credential.user!,
              authMethod: 'email',
            );
          } catch (error) {
            bootstrapFailed = true;
            debugPrint('[AuthBootstrap] email login failed: $error');
          }
          try {
            await EmailActionService.syncCurrentUserEmailVerificationState();
          } catch (_) {
            // Best effort.
          }
          await _trackLogin(authMethod: 'email', isNewUser: false);
        }
        if (!mounted) return;
        showSuccessSnackBar(
          context,
          bootstrapFailed
              ? 'Connexion reussie, profil en cours de synchronisation…'
              : 'Connexion reussie',
        );
      } else {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential.user != null) {
          try {
            await UserProfileBootstrapService.ensureUserDocument(
              user: credential.user!,
              authMethod: 'email',
              isNewUserHint: true,
            );
          } catch (error) {
            bootstrapFailed = true;
            debugPrint('[AuthBootstrap] email signup failed: $error');
          }
          try {
            await EmailActionService.requestEmailVerificationEmail();
          } catch (error) {
            debugPrint('[EmailVerification] request failed: $error');
          }
          await _trackLogin(authMethod: 'email', isNewUser: true);
        }
        if (!mounted) return;
        showSuccessSnackBar(
          context,
          bootstrapFailed
              ? 'Compte cree. Profil en cours de synchronisation, verifiez votre e-mail.'
              : 'Compte cree. Verifiez votre e-mail.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, _friendlyEmailAuthError(e));
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
      final normalizedPhone =
          _normalizePhoneForSave(_phoneCountryCode, _phoneCtrl.text.trim());
      final favoriteCategoryKeys =
          _favoriteCategories.keys.toSet().toList(growable: false);
      final favoriteSubcategories = _favoriteCategories.values
          .expand((items) => items)
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pseudo': displayName,
        'displayName': displayName,
        'city': _cityCtrl.text.trim(),
        'postalCode': _cpCtrl.text.trim(),
        'phone': normalizedPhone,
        'phoneNumber': normalizedPhone,
        'phone_number': normalizedPhone,
        'phoneCountryCode': _phoneCountryCode,
        'email': _emailCtrl.text.trim(),
        'accountType': _accountType,
        'favoriteCategories': favoriteCategoryKeys,
        'selectedFavoriteCategories': favoriteCategoryKeys,
        'selectedFavoriteSubcategories': favoriteSubcategories,
        'favoriteCategoryMap': _favoriteCategories.map(
          (key, value) => MapEntry(
            key,
            value.toSet().toList(growable: false),
          ),
        ),
        'preferences': {
          'notifNearby': _savedSearchEmailMode != 'off',
          'notifFavorites': _notifFavorites,
          'notifAcceptOffer': _notifAcceptOffer,
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

      _dirtyProfileFields.clear();

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
        'push': {
          'messaging': {'enabled': _notifAcceptOffer},
          'listings': {'enabled': _listingEmailMode != 'off'},
          'saved_searches': {'enabled': _savedSearchEmailMode != 'off'},
          'favorites': {'enabled': _notifFavorites},
          'support': {'enabled': _notifSystem},
        },
        'updatedAt': FieldValue.serverTimestamp(),
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

    await FirebaseFirestore.instance.collection('support_tickets').add(payload);

    return ticketNumber;
  }

  Future<void> _openSupportTicketComposer() async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final overlayTheme = context.prestoOverlayTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: overlayTheme.surfaceColor,
        surfaceTintColor: overlayTheme.surfaceTintColor,
        shape: overlayTheme.dialogShape,
        title: const Text(
          'Contacter le support',
          style: kPrestoSectionTitleStyle,
        ),
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

    final hasPasswordProvider = user?.providerData
            .any((provider) => provider.providerId == 'password') ??
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
    final overlayTheme = context.prestoOverlayTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: overlayTheme.surfaceColor,
        surfaceTintColor: overlayTheme.surfaceTintColor,
        shape: overlayTheme.dialogShape,
        title: const Text(
          'Changer mon mot de passe',
          style: kPrestoSectionTitleStyle,
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Mot de passe actuel'),
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
                decoration:
                    const InputDecoration(labelText: 'Nouveau mot de passe'),
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
                decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe'),
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
      showErrorSnackBar(
          context, e.message ?? 'Erreur de changement de mot de passe.');
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
        description:
            'Je souhaite recevoir un export de mes données personnelles et de mon historique d’activité lié à mon compte PRESTO.',
        category: 'data_export',
        priority: 'high',
      );
      if (!mounted) return;
      showSuccessSnackBar(
          context, 'Demande d’export enregistrée. Référence: $ticketNumber');
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

  Future<void> _onOpenMessagesTapped() async {
    await Navigator.of(context).pushNamed(buildMessagesRoute());
  }

  Future<void> _onOpenMessagesV2Tapped() async {
    await Navigator.of(context).pushNamed(buildMessagesV2Route());
  }

  Future<void> _onDeleteAccountTapped() async {
    final overlayTheme = context.prestoOverlayTheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: overlayTheme.surfaceColor,
        surfaceTintColor: overlayTheme.surfaceTintColor,
        shape: overlayTheme.dialogShape,
        title: const Text(
          'Supprimer mon compte',
          style: kPrestoSectionTitleStyle,
        ),
        content: const Text(
          'Cette action est irréversible. Veux-tu vraiment supprimer ton compte ?',
          style: kPrestoBodyTextStyle,
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
        description:
            'Je confirme demander la suppression de mon compte PRESTO et l’effacement associé de mes données, sous réserve des obligations légales de conservation.',
        category: 'account_deletion',
        priority: 'high',
      );
      if (!mounted) return;
      showSuccessSnackBar(context,
          'Demande de suppression enregistrée. Référence: $ticketNumber');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(
          context, 'Impossible de créer la demande de suppression: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onLogout() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await NotificationService().detachCurrentDevice();
      await _auth.signOut().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      showSuccessSnackBar(context, 'Déconnecté');
    } on TimeoutException {
      if (!mounted) return;
      showErrorSnackBar(context, 'La déconnexion a expiré. Réessayez.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur déconnexion: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onForgotPassword() async {
    if (_isLoading) return;

    final email = _emailCtrl.text.trim().toLowerCase();
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
            backgroundColor: kIliPrestoOrange,
            foregroundColor: Colors.white,
            title: const Text(
              'Mon profil',
              style: kPrestoAppBarTitleStyle,
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: isLoggedIn
                ? const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFCF8),
                        Color(0xFFF4F8FF),
                        Colors.white,
                      ],
                    ),
                  )
                : const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kIliPrestoCream,
                        kIliPrestoSky,
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
                        color: kIliPrestoOrange.withOpacity(0.10),
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
                        color: kIliPrestoBlue.withOpacity(0.10),
                      ),
                    ),
                  ),
                SafeArea(
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.fromLTRB(16, 16, 16, isLoggedIn ? 28 : 72),
                    child: isLoggedIn
                        ? (_isProfileHydrating
                            ? _buildProfileLoadingContent(colorScheme)
                            : _buildProfileContent(colorScheme, isDark, user))
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kIliPrestoOrange,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kIliPrestoOrange.withOpacity(0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _authHeadline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _authSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: kIliPrestoTextMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),

        // ── Social sign-in ───────────────────────────────────────────────────
        _buildSocialButton(
          icon: const _GoogleBrandLogo(size: 20),
          label: 'Continuer avec Google',
          onTap: () async => _onGoogleSignIn(),
          colorScheme: colorScheme,
          forceWhiteBackground: true,
        ),
        const SizedBox(height: 10),
        _buildSocialButton(
          icon: const FaIcon(FontAwesomeIcons.facebookF, size: 18, color: Color(0xFF1877F2)),
          label: 'Continuer avec Facebook',
          onTap: () async => _onFacebookSignIn(),
          colorScheme: colorScheme,
        ),
        if (_isAppleSignInSupported) ...[
          const SizedBox(height: 10),
          _buildSocialButton(
            icon: const Icon(Icons.apple, size: 22),
            label: 'Continuer avec Apple',
            onTap: () async => _onAppleSignIn(),
            colorScheme: colorScheme,
          ),
        ],

        // ── Divider ──────────────────────────────────────────────────────────
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: const Color(0xFF9CA3AF).withOpacity(0.40))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'ou par e-mail',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9CA3AF).withOpacity(0.85),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Expanded(child: Divider(color: const Color(0xFF9CA3AF).withOpacity(0.40))),
          ],
        ),
        const SizedBox(height: 20),

        // ── Email form ───────────────────────────────────────────────────────
        Form(
          key: _formKeyAuth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: _authInputDecoration(
                  labelText: 'Adresse e-mail',
                  prefixIcon: const Icon(Icons.email_outlined),
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
                  if (_authMode == AuthMode.login) _onEmailAuth();
                },
                decoration: _authInputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
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
                  decoration: _authInputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
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
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _isLoading ? null : () async => _onEmailAuth(),
                style: FilledButton.styleFrom(
                  backgroundColor: kIliPrestoOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _isLoading
                      ? 'Chargement...'
                      : _authMode == AuthMode.login
                          ? 'Se connecter'
                          : 'Créer mon compte',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (_authMode == AuthMode.login) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : () => _onForgotPassword(),
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(
                        color: kIliPrestoBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Mode toggle ──────────────────────────────────────────────────────
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              _authMode = _authMode == AuthMode.login ? AuthMode.signup : AuthMode.login;
            }),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: kIliPrestoTextMuted),
                children: [
                  TextSpan(
                    text: _authMode == AuthMode.login
                        ? 'Pas encore de compte ? '
                        : 'Déjà un compte ? ',
                  ),
                  TextSpan(
                    text: _authMode == AuthMode.login ? 'S\'inscrire' : 'Se connecter',
                    style: const TextStyle(
                      color: kIliPrestoBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Promo cards ──────────────────────────────────────────────────────
        const SizedBox(height: 28),
        _buildProAccessCard(),
        const SizedBox(height: 20),
        _buildPrestoPromoCard(colorScheme),
      ],
    );
  }

  Widget _buildProfileLoadingContent(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: kIliPrestoOrange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement du profil…',
              style: kPrestoBodyTextStyle.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
          backgroundColor:
              forceWhiteBackground ? Colors.white : const Color(0xFFF9FBFF),
          foregroundColor: const Color(0xFF111827),
          side: BorderSide(
            color: forceWhiteBackground
                ? kIliPrestoBorder
                : kIliPrestoBlue.withOpacity(0.24),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        ),
      ),
    );
  }

  Widget _buildPrestoPromoCard(ColorScheme colorScheme) {
    return Card(
      color: const Color(0xFFEAF2FF),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.bolt, color: kIliPrestoBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Besoin d'un jardinier tout de suite ? Publiez votre offre : ils sont des dizaines autour de vous, prêts à accepter le job !",
                style: const TextStyle(
                  color: Color(0xFF153B73),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProAccessCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6600).withOpacity(0.12),
            const Color(0xFF1A73E8).withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF6600).withOpacity(0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6600),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vous êtes une entreprise ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Créez votre profil Pro pour préparer votre présence sur iLiPresto et accéder aux options dédiées.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProProfilePage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kIliPrestoOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.business_center_outlined),
              label: const Text(
                'Créer un compte Pro',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _authInputDecoration({
    required String labelText,
    required Widget prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: kIliPrestoTextMuted,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: IconTheme(
        data: const IconThemeData(color: kIliPrestoBlue),
        child: prefixIcon,
      ),
      filled: true,
      fillColor: const Color(0xFFFBFDFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kIliPrestoBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kIliPrestoBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kIliPrestoBlue, width: 1.6),
      ),
    );
  }

  Widget _buildProfileContent(ColorScheme colorScheme, bool isDark, User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header profil
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kIliPrestoOrange,
                kIliPrestoBlue,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: kIliPrestoBlue.withOpacity(0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/logowebp.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.isEmpty
                          ? 'Mon profil iLiPresto'
                          : _nameCtrl.text,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Compte non verifie',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _onLogout,
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Déconnexion',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Infos personnelles
        _buildSectionTitle('Informations personnelles'),
        _buildProfileCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKeyProfile,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _profileInputDecoration(
                      labelText: 'Nom complet',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityCtrl,
                    decoration: _profileInputDecoration(
                      labelText: 'Commune',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cpCtrl,
                    decoration: _profileInputDecoration(
                      labelText: 'C/P',
                      prefixIcon: const Icon(Icons.markunread_mailbox_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  PhoneInputFieldCompact(
                    controller: _phoneCtrl,
                    initialCountryCode: _phoneCountryCode,
                    labelText: 'Téléphone',
                    hintText: phoneHintForCountryCode(_phoneCountryCode),
                    onCountryCodeChanged: (code) {
                      if (_phoneCountryCode == code) return;
                      setState(() {
                        _phoneCountryCode = code;
                      });
                      _dirtyProfileFields.add('phone');
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: _profileInputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: const Icon(Icons.email_outlined),
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
                                _dirtyProfileFields.add('accountType');
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
                      style: FilledButton.styleFrom(
                        backgroundColor: kIliPrestoOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
        _buildProfileCard(
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
                    DropdownMenuItem(
                        value: 'weekly', child: Text('Hebdomadaire')),
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
                    DropdownMenuItem(
                        value: 'immediate', child: Text('Immédiat')),
                    DropdownMenuItem(
                        value: 'digest_daily', child: Text('Digest quotidien')),
                    DropdownMenuItem(
                        value: 'digest_weekly',
                        child: Text('Digest hebdomadaire')),
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
                    DropdownMenuItem(
                        value: 'immediate', child: Text('Immédiat')),
                    DropdownMenuItem(
                        value: 'digest_daily', child: Text('Digest quotidien')),
                    DropdownMenuItem(
                        value: 'digest_weekly',
                        child: Text('Digest hebdomadaire')),
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
                  subtitle:
                      'Recevoir conseils, nouveautés et sélection PRESTO.',
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
        _buildProfileCard(
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
                          DropdownMenuItem(
                              value: '20:00', child: Text('20:00')),
                          DropdownMenuItem(
                              value: '21:00', child: Text('21:00')),
                          DropdownMenuItem(
                              value: '22:00', child: Text('22:00')),
                          DropdownMenuItem(
                              value: '23:00', child: Text('23:00')),
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
                          DropdownMenuItem(
                              value: '06:00', child: Text('06:00')),
                          DropdownMenuItem(
                              value: '07:00', child: Text('07:00')),
                          DropdownMenuItem(
                              value: '08:00', child: Text('08:00')),
                          DropdownMenuItem(
                              value: '09:00', child: Text('09:00')),
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
        _buildProfileCard(
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
                      color: kIliPrestoTextMuted,
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
                                  backgroundColor: const Color(0xFFEAF2FF),
                                  side:
                                      const BorderSide(color: kIliPrestoBorder),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: kIliPrestoBlue,
                      side: const BorderSide(color: kIliPrestoBorder),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        _buildSectionTitle('Messagerie'),
        _buildProfileCard(
          child: Column(
            children: [
              _buildProfileActionTile(
                icon: Icons.forum_outlined,
                title: 'Ouvrir mes messages',
                onTap: _onOpenMessagesV2Tapped,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Sécurité & aide
        _buildSectionTitle('Sécurité & aide'),
        _buildProfileCard(
          child: Column(
            children: [
              _buildProfileActionTile(
                icon: Icons.lock_reset_outlined,
                title: 'Changer mon mot de passe',
                onTap: _onChangePasswordTapped,
              ),
              const Divider(height: 0),
              _buildProfileActionTile(
                icon: Icons.description_outlined,
                title: 'Télécharger mes données',
                onTap: _onDownloadDataTapped,
              ),
              const Divider(height: 0),
              _buildProfileActionTile(
                icon: Icons.support_agent_outlined,
                title: 'FAQ & support',
                onTap: _onSupportTapped,
              ),
              const Divider(height: 0),
              _buildProfileActionTile(
                icon: Icons.delete_forever_outlined,
                title: 'Supprimer mon compte',
                iconColor: colorScheme.error,
                textColor: colorScheme.error,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 24,
            decoration: BoxDecoration(
              color: kIliPrestoOrange,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: kPrestoSectionTitleStyle.copyWith(
              color: const Color(0xFF16324F),
            ),
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
              Text(
                title,
                style:
                    kPrestoBodyTextStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: kPrestoMetaTextStyle.copyWith(
                  color: kIliPrestoTextMuted,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: kIliPrestoOrange,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFD1D5DB),
        ),
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
    final overlayTheme = context.prestoOverlayTheme;
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: overlayTheme.surfaceColor,
      borderRadius: overlayTheme.popupRadius,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(
          color: kIliPrestoTextMuted,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: kIliPrestoBlue) : null,
        filled: true,
        fillColor: const Color(0xFFFBFDFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kIliPrestoBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kIliPrestoBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kIliPrestoBlue, width: 1.6),
        ),
      ),
      items: items,
      onChanged: onChanged,
      menuMaxHeight: 250,
    );
  }

  InputDecoration _profileInputDecoration({
    required String labelText,
    required Widget prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: kIliPrestoTextMuted,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: IconTheme(
        data: const IconThemeData(color: kIliPrestoBlue),
        child: prefixIcon,
      ),
      filled: true,
      fillColor: const Color(0xFFFBFDFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kIliPrestoBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kIliPrestoBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kIliPrestoBlue, width: 1.6),
      ),
    );
  }

  Widget _buildProfileCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kIliPrestoBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildProfileActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (iconColor ?? kIliPrestoBlue).withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? kIliPrestoBlue),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? const Color(0xFF16324F),
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: kIliPrestoTextMuted),
      onTap: onTap,
    );
  }

  void _showAddCategoryDialog() {
    final overlayTheme = context.prestoOverlayTheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: overlayTheme.surfaceColor,
        surfaceTintColor: overlayTheme.surfaceTintColor,
        shape: overlayTheme.dialogShape,
        title: const Text(
          'Ajouter une catégorie',
          style: kPrestoSectionTitleStyle,
        ),
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
                        style: kPrestoBodyTextStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...allSubs.map((sub) {
                      final isFavored =
                          _favoriteCategories[category]?.contains(sub) ?? false;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: overlayTheme.selectionAccentColor,
                        checkColor: Colors.white,
                        tileColor: isFavored
                            ? overlayTheme.selectionFillColor
                            : Colors.transparent,
                        title: Text(sub,
                            style: kPrestoMetaTextStyle.copyWith(fontSize: 13)),
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
