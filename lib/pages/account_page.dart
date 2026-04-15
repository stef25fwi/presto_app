// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_element_parameter

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../app/presto_overlay_theme.dart';
import '../app_core.dart';
import '../constants.dart';
import '../features/account/signed_out_account_fallback.dart';
import '../models/admin_access_state.dart';
import 'admin_space_page.dart';
import '../services/admin_access_resolver.dart';
import '../services/account_social_auth_actions.dart';
import '../services/google_auth_service.dart';
import '../services/email_action_service.dart';
import '../services/firebase_functions_region.dart';
import '../services/notification_service.dart';
import '../services/user_profile_bootstrap_service.dart';
import '../utils/crashlytics_context.dart';
import '../utils/friendly_snackbar.dart';
import '../widgets/account_profile_sections.dart';

import '../main.dart' show
    PrestoMonitoring,
    prestoOverlayStyleFor,
    adminAudioRuntimeStore;
import 'user_offers_section.dart';

/// PAGE COMPTE (Firebase Auth : email / Google / Apple) ////////////////////

class AccountPage extends StatefulWidget {
  final Function(double)? onScroll;
  final bool startInSignup;

  const AccountPage({super.key, this.onScroll, this.startInSignup = false});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final AdminAccessResolver _adminAccessResolver = AdminAccessResolver();

  final FirebaseFunctions _functions = prestoFirebaseFunctions;

  Future<void> _trackLogin({
    String? authMethod,
    bool isNewUser = false,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // ✅ Métriques enrichies
      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      final deviceType = _getDeviceType();

      final callable = _functions.httpsCallable(
        'trackUserLogin',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );

      await callable.call<dynamic>({
        'authMethod': authMethod,
        'platform': platform,
        'deviceType': deviceType,
        'isNewUser': isNewUser,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      sw.stop();
      PrestoMonitoring.I.trackFunctionsCall(
          name: 'trackUserLogin', ms: sw.elapsedMilliseconds);
    } catch (e) {
      PrestoMonitoring.I.trackError('trackUserLogin', e);
      debugPrint('[Tracking] Error: $e');
    }
  }

  String _getDeviceType() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  // final _formKey = GlobalKey<FormState>(); // Plus utilisé avec PrestoPremiumAuthPage

  // Email / mot de passe - Maintenant gérés par PrestoPremiumAuthPage
  // final _emailController = TextEditingController();
  // final _passwordController = TextEditingController();
  // final _passwordConfirmController = TextEditingController();

  // Profil utilisateur
  final TextEditingController _profilePseudoController =
      TextEditingController();
  final TextEditingController _profileCityController = TextEditingController();
  final TextEditingController _profilePhoneController = TextEditingController();
  String _profilePhoneCountryCode = '+33';
  StreamSubscription<User?>? _profileAuthSub;
  String? _activeProfileUid;

  Set<String> _favoriteCategories = <String>{};
  Set<String> _selectedFavoriteCategories = <String>{};
  Set<String> _selectedFavoriteSubcategories = <String>{};
  Set<String> _draftFavoriteSelections = <String>{};
  bool _profileLoaded = false;
  bool _profileLoadRequested = false;
  bool _isSavingProfile = false;
  bool _isSigningOut = false;
  bool _isEditingProfile = false; // ✅ Mode édition du profil
  bool _isPublishedOffersExpanded = false;
  bool _isFavoriteOffersExpanded = false;
  bool _profileLoadError = false;
  int _profileLoadRetries = 0;
  static const int _maxProfileLoadRetries = 3;
  int _lastMissingRequiredCount = -1;

  static const List<String> _requiredProfileFieldLabels = <String>[
    'Pseudo',
    'Ville',
    'Numéro de téléphone',
  ];

  Future<AdminAccessState>? _adminAccessFuture;
  String? _adminAccessFutureUid;
  AdminAccessState? _lastAdminAccessState;
  Future<Map<String, dynamic>>? _adminCfgFuture;
  String? _adminCfgFutureUid;
  DateTime? _adminLastCheckedAt;

  void _resetAdminAccessState() {
    _adminAccessFuture = null;
    _adminAccessFutureUid = null;
    _lastAdminAccessState = null;
    _adminCfgFuture = null;
    _adminCfgFutureUid = null;
    _adminLastCheckedAt = null;
  }

  bool _shouldShowAdminDebugCard(
    User user, {
    AdminAccessState? state,
  }) {
    final resolvedState = state ?? _lastAdminAccessState;
    final email = (user.email ?? '').trim().toLowerCase();
    return email == 'sahai.stephane@gmail.com' ||
        (resolvedState?.effectiveIsAdmin ?? false) ||
        resolvedState?.serverErrorCode != null;
  }

  String _adminDebugText(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'oui' : 'non';
    if (value is Iterable) {
      final items = value.map((entry) => entry.toString()).toList();
      return items.isEmpty ? '-' : items.join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  String _adminLocalSource(AdminAccessState state) {
    final sources = <String>[];
    if (state.tokenHasAdmin) {
      sources.add('token');
    }
    if (state.profileHasAdmin) {
      sources.add('profil');
    }
    if (state.adminDocHasAdmin) {
      sources.add('adminDoc');
    }
    if (sources.isEmpty) {
      return '';
    }
    return sources.join('+');
  }

  List<String> _adminStatusMessages(AdminAccessState state) {
    final messages = <String>[];
    if (!state.isAuthenticated) {
      messages.add('Utilisateur non authentifié');
    }

    if (state.tokenHasAdmin) {
      messages.add('Accès admin confirmé par le token');
    }

    if (state.tokenHasAdmin && state.profileLoaded && !state.profileHasAdmin) {
      messages.add('Profil Firestore non synchronisé avec les claims admin');
    }

    if (state.serverCheckAttempted && !state.serverCheckSucceeded) {
      messages.add(
        state.serverErrorCode == 'unauthenticated'
            ? 'Vérification serveur temporairement indisponible'
            : 'Vérification serveur indisponible',
      );
    }
    if (state.effectiveIsAdmin &&
        state.serverCheckAttempted &&
        !state.serverCheckSucceeded) {
      messages.add('Accès admin confirmé malgré échec serveur');
    }
    return messages;
  }

  bool _adminShouldUseLocalFallback(AdminAccessState state) {
    if (!state.effectiveIsAdmin) {
      return false;
    }
    if (state.serverCheckAttempted && !state.serverCheckSucceeded) {
      return true;
    }
    return state.serverCheckSucceeded &&
        state.serverIsAdmin != true &&
        state.hasLocalAdminEvidence;
  }

  String _adminFallbackMessage(AdminAccessState state) {
    final messages = _adminStatusMessages(state);
    if (messages.isEmpty) {
      return 'Accès admin local confirmé. La vérification serveur reste complémentaire pour ce profil.';
    }
    return messages.join('. ');
  }

  void _refreshAdminAccessForUser(
    String uid, {
    bool forceRefresh = false,
  }) {
    _adminAccessFutureUid = uid;
    final future = _adminAccessResolver.resolveAdminAccess(
      forceRefresh: forceRefresh,
    );
    _adminAccessFuture = future;
    unawaited(
      future.then((state) {
        if (!mounted || _adminAccessFuture != future) {
          return;
        }
        setState(() {
          _lastAdminAccessState = state;
          _adminLastCheckedAt = state.serverCheckedAt ?? _adminLastCheckedAt;
        });
        if (state.effectiveIsAdmin) {
          unawaited(adminAudioRuntimeStore.enableCloudSync());
        }
      }).catchError((Object error, StackTrace stackTrace) {
        debugPrint('[AdminProfile] admin access resolution failed: $error');
      }),
    );
  }

  Map<String, dynamic> _adminServerDebug(AdminAccessState state) {
    return state.serverDebug;
  }

  String _adminStateErrorDetail(AdminAccessState state) {
    final code = state.serverErrorCode?.trim();
    final message = state.serverErrorMessage?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    switch (code) {
      case 'permission-denied':
        return 'Accès refusé par la fonction admin.';
      case 'unauthenticated':
        return 'La session n’a pas encore été validée côté serveur. Recharge la page ou reconnecte-toi.';
      case 'unavailable':
        return 'Le service admin est indisponible ou le réseau ne répond pas.';
      case 'deadline-exceeded':
        return 'La vérification admin a dépassé le délai autorisé.';
      case 'internal':
        return 'La fonction admin a renvoyé une erreur interne.';
      case 'unknown':
        return 'La vérification admin a échoué de manière inattendue.';
    }
    return 'Détail indisponible.';
  }

  String _adminConfigSourceLabel(AdminAccessState state) {
    if (state.sourceOfTruth == 'none') {
      return 'inconnu';
    }
    return state.sourceOfTruth;
  }

  Future<Map<String, dynamic>> _adminGetMicroIaConfig() async {
    final sw = Stopwatch()..start();
    final callable = _functions.httpsCallable(
      'adminGetMicroIaConfig',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    try {
      await _auth.currentUser?.getIdToken(true);
      final res = await callable.call<dynamic>({});
      sw.stop();
      PrestoMonitoring.I.trackFunctionsCall(
          name: 'adminGetMicroIaConfig', ms: sw.elapsedMilliseconds);
      unawaited(adminAudioRuntimeStore.enableCloudSync());
      return Map<String, dynamic>.from(res.data as Map);
    } catch (e) {
      PrestoMonitoring.I.trackError('adminGetMicroIaConfig', e);
      rethrow;
    }
  }

  void _refreshAdminConfigForUser(String uid) {
    _adminCfgFutureUid = uid;
    _adminCfgFuture = _adminGetMicroIaConfig();
  }

  bool _isAdminAccessDenied(Object? error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'permission-denied' ||
          error.code == 'unauthenticated';
    }

    final errStr = error?.toString() ?? '';
    return errStr.contains('permission-denied') ||
        errStr.contains('unauthenticated');
  }

  bool _isAdminAccessUnauthenticated(Object? error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'unauthenticated';
    }

    final errStr = error?.toString() ?? '';
    return errStr.contains('unauthenticated');
  }

  String _adminErrorDetail(Object? error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      switch (error.code) {
        case 'permission-denied':
          return 'Accès refusé par la fonction admin.';
        case 'unauthenticated':
          return 'La session n’a pas encore été validée côté serveur. Recharge la page ou reconnecte-toi.';
        case 'unavailable':
          return 'Le service admin est indisponible ou le réseau ne répond pas.';
        case 'deadline-exceeded':
          return 'La vérification admin a dépassé le délai autorisé.';
        case 'internal':
          return 'La fonction admin a renvoyé une erreur interne.';
      }
    }

    final errStr = error?.toString().trim() ?? '';
    final errLower = errStr.toLowerCase();
    if (errLower.contains('socketexception') ||
        errLower.contains('network') ||
        errLower.contains('failed host lookup')) {
      return 'Échec réseau pendant la vérification admin.';
    }
    if (errLower.contains('timeout') ||
        errLower.contains('deadline-exceeded')) {
      return 'La vérification admin a expiré.';
    }
    if (errStr.isEmpty) {
      return 'Détail indisponible.';
    }
    return errStr;
  }

  String _adminModeStatusLabel(String mode) {
    switch (mode) {
      case 'GOOGLE_ONLY':
        return 'Google uniquement';
      case 'WHISPER_ONLY':
        return 'Whisper uniquement';
      case 'HYBRID':
      default:
        return 'Hybride';
    }
  }

  String _formatAdminCheckTime(DateTime? value) {
    if (value == null) return 'inconnu';
    String two(int v) => v.toString().padLeft(2, '0');
    final local = value.toLocal();
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildAdminDebugCard(
    User user, {
    required AdminAccessState state,
  }) {
    final serverDebug = _adminServerDebug(state);
    final serverCheckedAt = state.serverCheckedAt ?? _adminLastCheckedAt;
    final localSource = _adminLocalSource(state);
    final statusMessages = _adminStatusMessages(state);
    final recentSteps = state.debugSteps.length > 5
        ? state.debugSteps.sublist(state.debugSteps.length - 5)
        : state.debugSteps;
    final lines = <String>[
      'uid=${user.uid}',
      'email=${_adminDebugText(state.email ?? user.email)}',
      'localHint=${_adminDebugText(state.hasLocalAdminEvidence)}',
      'localSource=${_adminDebugText(localSource)}',
      'tokenHasAdmin=${_adminDebugText(state.tokenHasAdmin)}',
      'tokenRoles=${_adminDebugText(state.tokenRoles)}',
      'profileHasAdmin=${_adminDebugText(state.profileHasAdmin)}',
      'profileRoles=${_adminDebugText(state.profileRoles)}',
      'profilePrimaryRole=${_adminDebugText(state.profilePrimaryRole)}',
      'adminDocHasAdmin=${_adminDebugText(state.adminDocHasAdmin)}',
      'serverIsAdmin=${_adminDebugText(state.serverIsAdmin)}',
      'serverSource=${_adminDebugText(state.serverSource)}',
      'serverCheckedAt=${_formatAdminCheckTime(serverCheckedAt)}',
      'server.tokenHasAdmin=${_adminDebugText(serverDebug['tokenHasAdmin'])}',
      'server.userDocExists=${_adminDebugText(serverDebug['userDocExists'])}',
      'server.userHasAdmin=${_adminDebugText(serverDebug['userHasAdmin'])}',
      'server.userRoles=${_adminDebugText(serverDebug['userRoles'])}',
      'server.userPrimaryRole=${_adminDebugText(serverDebug['userPrimaryRole'])}',
      'server.adminDocExists=${_adminDebugText(serverDebug['adminDocExists'])}',
      'server.adminDocEnabled=${_adminDebugText(serverDebug['adminDocEnabled'])}',
      'server.errorCode=${_adminDebugText(state.serverErrorCode)}',
      'server.errorMessage=${_adminDebugText(state.serverErrorMessage)}',
      'sourceOfTruth=${_adminDebugText(state.sourceOfTruth)}',
      'lastStage=${_adminDebugText(state.lastStage)}',
      if (statusMessages.isNotEmpty) 'messages=${statusMessages.join(' | ')}',
      if (recentSteps.isNotEmpty) 'debugSteps=${recentSteps.join(' | ')}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9DDEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_rounded, color: Colors.black54),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Diagnostic admin visible',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _refreshAdminAccessForUser(user.uid, forceRefresh: true);
                    _adminCfgFuture = null;
                    _adminCfgFutureUid = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Relancer'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            lines.join('\n'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrestoBlue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrestoBlue.withOpacity(0.18)),
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification admin en cours',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chargement des droits et de la configuration Micro-IA pour ce profil.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminLoadRetryCard({
    required User user,
    required String title,
    required String message,
    String? detail,
    bool showOpenButton = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          if (detail != null && detail.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Détail: ${detail.trim()}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _refreshAdminAccessForUser(user.uid, forceRefresh: true);
                _refreshAdminConfigForUser(user.uid);
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
          if (showOpenButton) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminSpacePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text("Ouvrir l'espace admin"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrestoOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const List<String> _allFavoriteCategories = [
    'Restauration / Extra',
    'Bricolage / Travaux',
    'Aide à domicile',
    'Garde d’enfants',
    'Événementiel / DJ',
    'Cours & soutien',
    'Jardinage',
    'Peinture',
    'Main-d’œuvre',
    'Autre',
  ];

  static const Map<String, List<String>> _subCategoriesByCategory = {
    'Restauration / Extra': ['Service', 'Plonge', 'Cuisine', 'Bar'],
    'Bricolage / Travaux': [
      'Montage meuble',
      'Électricité',
      'Plomberie',
      'Peinture'
    ],
    'Aide à domicile': ['Ménage', 'Repassage', 'Courses'],
    'Garde d’enfants': ['Sortie d’école', 'Soirée', 'Mercredi'],
    'Événementiel / DJ': ['DJ', 'Sono', 'Lumières'],
    'Cours & soutien': ['Maths', 'Langues', 'Musique'],
    'Jardinage': ['Tonte', 'Taille', 'Désherbage'],
    'Peinture': ['Intérieur', 'Extérieur'],
    'Main-d’œuvre': ['Manutention', 'Aide chantier'],
    'Autre': ['Général'],
  };

  @override
  void initState() {
    super.initState();
    unawaited(adminAudioRuntimeStore.ensureInitialized());
    // _isLoginMode = !widget.startInSignup; // Plus utilisé avec PrestoPremiumAuthPage
    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });
    _profilePseudoController.addListener(_handleProfileCompletenessChanged);
    _profileCityController.addListener(_handleProfileCompletenessChanged);
    _profilePhoneController.addListener(_handleProfileCompletenessChanged);
    _profileAuthSub = _auth.idTokenChanges().listen((user) {
      if (!mounted) return;
      unawaited(_handleProfileAuthStateChanged(user));
    });

    // Sur Web, vérifie si l'utilisateur revient d'un redirect Google Sign-In
    if (kIsWeb) {
      _checkGoogleRedirectResult();
    }
  }

  void _handleProfileCompletenessChanged() {
    if (!mounted) return;
    final nextMissingCount = _missingRequiredProfileFields().length;
    if (nextMissingCount == _lastMissingRequiredCount) {
      return;
    }
    setState(() {
      _lastMissingRequiredCount = nextMissingCount;
    });
  }

  void _resetProfileState({
    bool clearControllers = true,
  }) {
    _activeProfileUid = null;
    _profileLoaded = false;
    _profileLoadRequested = false;
    _profileLoadError = false;
    _profileLoadRetries = 0;
    _lastMissingRequiredCount = -1;
    _isEditingProfile = false;
    _profilePhoneCountryCode = '+33';
    _favoriteCategories = <String>{};
    _selectedFavoriteCategories = <String>{};
    _selectedFavoriteSubcategories = <String>{};
    _draftFavoriteSelections = <String>{};
    _resetAdminAccessState();

    if (clearControllers) {
      _profilePseudoController.clear();
      _profileCityController.clear();
      _profilePhoneController.clear();
    }
  }

  Future<void> _handleProfileAuthStateChanged(User? user) async {
    if (!mounted) return;

    if (user == null) {
      SessionState.userId = null;
      setState(() {
        _resetProfileState();
      });
      return;
    }

    SessionState.userId = user.uid;

    try {
      await UserProfileBootstrapService.ensureUserDocument(
        user: user,
        authMethod: 'session_restore',
      );
    } catch (error) {
      debugPrint('[AuthBootstrap] account session restore failed: $error');
      if (mounted) {
        showErrorSnackBar(
          context,
          'Impossible de synchroniser le profil. Vérifie ta connexion.',
        );
      }
    }

    if (_activeProfileUid == user.uid &&
        (_profileLoaded || _profileLoadRequested)) {
      if (!mounted) return;
      setState(() {
        _refreshAdminAccessForUser(user.uid);
      });
      return;
    }

    setState(() {
      _resetProfileState(clearControllers: false);
      _activeProfileUid = user.uid;
      final displayName = user.displayName?.trim() ?? '';
      _profilePseudoController.text = displayName;
      _profileLoadRequested = true;
      _refreshAdminAccessForUser(user.uid, forceRefresh: true);
    });

    await _loadUserProfile(user);
  }

  bool _hasProfileValuesInMemory() {
    return _profilePseudoController.text.trim().isNotEmpty ||
        _profileCityController.text.trim().isNotEmpty ||
        _profilePhoneController.text.trim().isNotEmpty;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserProfileDocument(
    String uid,
  ) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      return await userRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('[Profile] Fallback cache pour le profil: $error');
      return userRef
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 3));
    }
  }

  String _firstNonEmptyProfileValue(
    Map<String, dynamic>? data,
    List<String> keys, {
    List<String> fallbackValues = const <String>[],
  }) {
    if (data != null) {
      for (final key in keys) {
        final raw = data[key];
        final value = raw?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    for (final fallback in fallbackValues) {
      final value = fallback.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _normalizeProfilePhoneForSave(String countryCode, String rawPhone) {
    final codeDigits = countryCode.replaceAll(RegExp(r'\D'), '');
    var phoneDigits = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (codeDigits.isEmpty || phoneDigits.isEmpty) {
      return '';
    }

    if (phoneDigits.startsWith('00')) {
      phoneDigits = phoneDigits.substring(2);
    }

    if (phoneDigits.startsWith(codeDigits)) {
      return '+$phoneDigits';
    }

    if (phoneDigits.startsWith('0')) {
      phoneDigits = phoneDigits.substring(1);
    }

    return '+$codeDigits$phoneDigits';
  }

  void _applyLoadedProfilePhone(String rawPhone) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) {
      _profilePhoneCountryCode = '+33';
      _profilePhoneController.text = '';
      return;
    }

    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    const knownCodes = <String>['+590', '+596', '+594', '+689', '+262', '+33'];

    for (final code in knownCodes) {
      if (!compact.startsWith(code)) continue;

      final codeDigits = code.replaceAll(RegExp(r'\D'), '');
      final allDigits = compact.replaceAll(RegExp(r'\D'), '');
      final localDigits = allDigits.substring(codeDigits.length);

      _profilePhoneCountryCode = code;
      _profilePhoneController.text = localDigits;
      return;
    }

    _profilePhoneCountryCode = '+33';
    _profilePhoneController.text = trimmed;
  }

  Future<void> _checkGoogleRedirectResult() async {
    try {
      final result = await _auth.getRedirectResult();
      if (result.user != null) {
        final isNew = result.additionalUserInfo?.isNewUser ?? false;
        // Créer/mettre à jour le document Firestore de l'utilisateur
        // (manquant avant : les nouveaux utilisateurs via redirect n'avaient pas de document).
        try {
          await UserProfileBootstrapService.ensureUserDocument(
            user: result.user!,
            authMethod: 'google',
            isNewUserHint: isNew,
          );
        } catch (bootstrapError) {
          debugPrint('[Google Redirect] Bootstrap error: $bootstrapError');
        }
        await _trackLogin(authMethod: 'google', isNewUser: isNew);
        if (!mounted) return;
        showSuccessSnackBar(context, "Connecté avec Google");
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = "Erreur Google";
      var shouldShow = true;
      if (e.code == 'unauthorized-domain') {
        msg =
            "Domaine non autorisé. Ajoute ce domaine dans Firebase Console → Authentication → Authorized domains.";
      } else if (e.code == 'operation-not-allowed') {
        msg =
            "Google Sign-In non activé. Active-le dans Firebase Console → Authentication → Sign-in method.";
      } else if (e.code != 'invalid-credential' && e.code != 'no-auth-event') {
        msg = "Erreur Google : ${e.message ?? e.code}";
      } else {
        shouldShow = false;
      }

      if (shouldShow) {
        showErrorSnackBar(context, msg);
      }
    } catch (e) {
      debugPrint('[Google Redirect] Error checking result: $e');
    }
  }

  @override
  void dispose() {
    // _emailController.dispose(); // Maintenant géré par PrestoPremiumAuthPage
    // _passwordController.dispose();
    // _passwordConfirmController.dispose();
    _profileAuthSub?.cancel();
    _profilePseudoController.removeListener(_handleProfileCompletenessChanged);
    _profileCityController.removeListener(_handleProfileCompletenessChanged);
    _profilePhoneController.removeListener(_handleProfileCompletenessChanged);
    _profilePseudoController.dispose();
    _profileCityController.dispose();
    _profilePhoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Ancienne méthode - maintenant gérée par PrestoPremiumAuthPage

  Future<void> _loadUserProfile(User user, {int attempt = 0}) async {
    final previousPseudo = _profilePseudoController.text.trim();
    final previousCity = _profileCityController.text.trim();
    final previousPhoneCountryCode = _profilePhoneCountryCode;
    final previousPhone = _profilePhoneController.text.trim();
    final previousFavoriteCategories = _favoriteCategories.toSet();
    final previousSelectedFavoriteCategories =
        _selectedFavoriteCategories.toSet();
    final previousSelectedFavoriteSubcategories =
        _selectedFavoriteSubcategories.toSet();
    final previousDraftFavoriteSelections = _draftFavoriteSelections.toSet();

    try {
      await EmailActionService.syncCurrentUserEmailVerificationState();
    } catch (e) {
      debugPrint('[Profile] Erreur synchro emailVerified: $e');
    }

    try {
      final doc = await _fetchUserProfileDocument(user.uid);

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _profilePseudoController.text = _firstNonEmptyProfileValue(
          data,
          const ['pseudo', 'displayName', 'userName', 'user_name', 'name'],
          fallbackValues: <String>[user.displayName ?? '', previousPseudo],
        );
        _profileCityController.text = _firstNonEmptyProfileValue(
          data,
          const ['city', 'location', 'serviceArea', 'service_area'],
          fallbackValues: <String>[previousCity],
        );

        final loadedPhone = _firstNonEmptyProfileValue(
          data,
          const ['phone', 'phoneNumber', 'phone_number'],
          fallbackValues: <String>[user.phoneNumber ?? ''],
        );
        if (loadedPhone.isNotEmpty) {
          _applyLoadedProfilePhone(loadedPhone);
        } else if (previousPhone.isNotEmpty) {
          _profilePhoneCountryCode = previousPhoneCountryCode;
          _profilePhoneController.text = previousPhone;
        } else {
          _applyLoadedProfilePhone('');
        }

        final favs = (data['favoriteCategories'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        final hasFavoriteCategoriesKey = data.containsKey('favoriteCategories');
        _favoriteCategories = hasFavoriteCategoriesKey
            ? favs.toSet()
            : previousFavoriteCategories;
        _draftFavoriteSelections = hasFavoriteCategoriesKey
            ? _favoriteCategories.toSet()
            : previousDraftFavoriteSelections;
        final selectedCats =
            (data['selectedFavoriteCategories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        final hasSelectedFavoriteCategoriesKey =
            data.containsKey('selectedFavoriteCategories');
        _selectedFavoriteCategories = hasSelectedFavoriteCategoriesKey
            ? selectedCats.toSet()
            : previousSelectedFavoriteCategories;
        final selectedSubcats =
            (data['selectedFavoriteSubcategories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        final hasSelectedFavoriteSubcategoriesKey =
            data.containsKey('selectedFavoriteSubcategories');
        _selectedFavoriteSubcategories = hasSelectedFavoriteSubcategoriesKey
            ? selectedSubcats.toSet()
            : previousSelectedFavoriteSubcategories;

        final hasStoredFavorites = hasFavoriteCategoriesKey ||
            hasSelectedFavoriteCategoriesKey ||
            hasSelectedFavoriteSubcategoriesKey;
        final mergedFavoriteSelections = <String>{
          ...favs,
          ...selectedCats,
          ...selectedSubcats,
        };
        if (hasStoredFavorites) {
          _favoriteCategories = mergedFavoriteSelections;
          _draftFavoriteSelections = mergedFavoriteSelections.toSet();
        }

        // ✅ Si les champs sont remplis, ne pas être en mode édition par défaut
        final hasProfile = _hasProfileValuesInMemory();
        _isEditingProfile = !hasProfile;
        _profileLoadError = false;
        _profileLoadRetries = 0;
      } else {
        _profilePseudoController.text =
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : previousPseudo;
        _profileCityController.text = previousCity;
        if (previousPhone.isNotEmpty) {
          _profilePhoneCountryCode = previousPhoneCountryCode;
          _profilePhoneController.text = previousPhone;
        }
        _favoriteCategories = previousFavoriteCategories;
        _selectedFavoriteCategories = previousSelectedFavoriteCategories;
        _selectedFavoriteSubcategories = previousSelectedFavoriteSubcategories;
        _draftFavoriteSelections = previousDraftFavoriteSelections;
        _isEditingProfile = !_hasProfileValuesInMemory();
        _profileLoadError = false;
      }
    } catch (e) {
      debugPrint('[Profile] Erreur chargement profil: $e');

      // Retry automatique jusqu'à 3 fois
      if (attempt < _maxProfileLoadRetries) {
        _profileLoadRetries = attempt + 1;
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _loadUserProfile(user, attempt: attempt + 1);
          return;
        }
      }

      if (previousPseudo.isNotEmpty && _profilePseudoController.text.isEmpty) {
        _profilePseudoController.text = previousPseudo;
      }
      if (previousCity.isNotEmpty && _profileCityController.text.isEmpty) {
        _profileCityController.text = previousCity;
      }
      if (previousPhone.isNotEmpty && _profilePhoneController.text.isEmpty) {
        _profilePhoneCountryCode = previousPhoneCountryCode;
        _profilePhoneController.text = previousPhone;
      }

      _favoriteCategories = previousFavoriteCategories;
      _selectedFavoriteCategories = previousSelectedFavoriteCategories;
      _selectedFavoriteSubcategories = previousSelectedFavoriteSubcategories;
      _draftFavoriteSelections = previousDraftFavoriteSelections;
      _profileLoadError = true;
      _isEditingProfile = !_hasProfileValuesInMemory();
    }

    if (mounted) {
      setState(() {
        _lastMissingRequiredCount = _missingRequiredProfileFields().length;
        _profileLoaded = true;
        _profileLoadRequested = true;
      });
    }
  }

  bool _validateProfile() {
    final pseudo = _profilePseudoController.text.trim();
    final city = _profileCityController.text.trim();
    final phone = _profilePhoneController.text.trim();
    final normalizedPhone =
        _normalizeProfilePhoneForSave(_profilePhoneCountryCode, phone);

    // Validation pseudo
    if (pseudo.isEmpty) {
      showErrorSnackBar(context, "Le pseudo est obligatoire");
      return false;
    }
    if (pseudo.length < 2) {
      showErrorSnackBar(
          context, "Le pseudo doit contenir au moins 2 caractères");
      return false;
    }
    if (pseudo.length > 50) {
      showErrorSnackBar(
          context, "Le pseudo ne doit pas dépasser 50 caractères");
      return false;
    }
    if (!RegExp(r'^[a-zA-Z0-9àâäæéèêëïîôùûüœçÀÂÄÆÉÈÊËÏÎÔÙÛÜŒÇ\s\-_\.]+$')
        .hasMatch(pseudo)) {
      showErrorSnackBar(context,
          "Le pseudo ne peut contenir que des lettres, chiffres et caractères spéciaux (-, _, .)");
      return false;
    }

    if (city.isEmpty) {
      showErrorSnackBar(context, "La ville est obligatoire");
      return false;
    }

    if (phone.isEmpty) {
      showErrorSnackBar(context, "Le numéro de téléphone est obligatoire");
      return false;
    }

    if (!RegExp(r'^\+[0-9]{10,15}$').hasMatch(normalizedPhone)) {
      showErrorSnackBar(
          context, "Le numéro de téléphone doit contenir 10-15 chiffres");
      return false;
    }

    return true;
  }

  List<String> _missingRequiredProfileFields() {
    final missing = <String>[];

    if (_profilePseudoController.text.trim().isEmpty) {
      missing.add('pseudo');
    }
    if (_profileCityController.text.trim().isEmpty) {
      missing.add('ville');
    }
    if (_profilePhoneController.text.trim().isEmpty) {
      missing.add('numéro de téléphone');
    }

    return missing;
  }

  double _calculateProfileCompleteness() {
    final missingCount = _missingRequiredProfileFields().length;
    final filled = _requiredProfileFieldLabels.length - missingCount;
    return filled / _requiredProfileFieldLabels.length;
  }

  Future<bool> _saveProfile(
    User user, {
    bool showSuccess = true,
  }) async {
    if (!mounted) return false;

    // Validation du profil
    if (!_validateProfile()) {
      return false;
    }

    setState(() => _isSavingProfile = true);
    try {
      final pseudo = _profilePseudoController.text.trim();
      final city = _profileCityController.text.trim();
      final phone = _profilePhoneController.text.trim();
      final normalizedPhone =
          _normalizeProfilePhoneForSave(_profilePhoneCountryCode, phone);

      final profileData = <String, dynamic>{
        'pseudo': pseudo,
        'displayName': pseudo,
        'userName': pseudo,
        'user_name': pseudo,
        'name': pseudo,
        'city': city,
        'location': city,
        'serviceArea': city,
        'service_area': city,
        'phone': normalizedPhone,
        'phoneNumber': normalizedPhone,
        'phone_number': normalizedPhone,
        'phoneCountryCode': _profilePhoneCountryCode,
        'favoriteCategories': _favoriteCategories.toList(),
        'selectedFavoriteCategories': _selectedFavoriteCategories.toList(),
        'selectedFavoriteSubcategories':
            _selectedFavoriteSubcategories.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileUpdatedAt': FieldValue.serverTimestamp(),
        'profileCompleteness': _calculateProfileCompleteness(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      // Mise à jour du displayName Firebase Auth
      if (pseudo.isNotEmpty) {
        try {
          await user.updateDisplayName(pseudo).timeout(
                const Duration(seconds: 5),
              );
          await user.reload().timeout(
                const Duration(seconds: 5),
              );
        } catch (e) {
          debugPrint('[Profile] Erreur mise à jour displayName: $e');
          // Continue même si échoue
        }
      }

      final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
      try {
        await _loadUserProfile(refreshedUser);
      } catch (e) {
        debugPrint('[Profile] Erreur rechargement profil après sauvegarde: $e');
      }

      // ✅ Vérifier l'email si pas encore vérifié
      if (!refreshedUser.emailVerified && refreshedUser.email != null) {
        try {
          await EmailActionService.requestEmailVerificationEmail();
        } catch (_) {
          // Silencieux
        }
      }

      if (mounted) {
        setState(() => _isEditingProfile = false);
        if (showSuccess) {
          showSuccessSnackBar(context, "Profil mis à jour avec succès");
        }
      }
      return true;
    } on FirebaseException catch (e) {
      if (mounted) {
        String errorMsg = 'Erreur lors de la sauvegarde du profil';
        if (e.code == 'permission-denied') {
          errorMsg = 'Vous n\'êtes pas autorisé à modifier ce profil';
        } else if (e.code == 'unavailable') {
          errorMsg = 'Service indisponible. Réessayez dans un instant';
        } else if (e.code == 'deadline-exceeded') {
          errorMsg = 'Délai d\'attente dépassé. Vérifiez votre connexion';
        } else if ((e.message ?? '').trim().isNotEmpty) {
          errorMsg = e.message!.trim();
        }
        showErrorSnackBar(context, errorMsg);
      }
      return false;
    } on TimeoutException {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Délai d\'attente dépassé. Vérifiez votre connexion',
        );
      }
      return false;
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Erreur lors de la sauvegarde du profil');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  void _mutateDraftCategory(
    String category, {
    Set<String>? selections,
  }) {
    final targetSelections = selections ?? _draftFavoriteSelections;

    if (targetSelections.contains(category)) {
      targetSelections.remove(category);
      targetSelections.removeWhere((e) => e.startsWith('$category — '));
    } else {
      targetSelections.add(category);
    }
  }

  void _mutateDraftSubcategory({
    required String category,
    required String subcategory,
    Set<String>? selections,
  }) {
    final targetSelections = selections ?? _draftFavoriteSelections;
    final label = '$category — $subcategory';
    if (targetSelections.contains(label)) {
      targetSelections.remove(label);
    } else {
      targetSelections.add(category);
      targetSelections.add(label);
    }
  }

  Future<void> _applyDraftFavorites(User user) async {
    final draft = _draftFavoriteSelections.toSet();

    final selectedCats = draft.where((e) => !e.contains('—')).toSet();
    final selectedSubcats = draft.where((e) => e.contains('—')).toSet();

    setState(() {
      _favoriteCategories = draft;
      _selectedFavoriteCategories = selectedCats;
      _selectedFavoriteSubcategories = selectedSubcats;
    });

    final ok = await _saveProfile(user, showSuccess: false);
    if (!mounted) return;
    if (ok) {
      showSuccessSnackBar(context, 'Alertes enregistrées');
    }
  }

  Future<void> _openCategoryPickerSheet() async {
    var workingSelections = _draftFavoriteSelections.toSet();
    final overlayTheme = context.prestoOverlayTheme;

    final validatedSelections = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Text(
                        'Choisir des catégories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _allFavoriteCategories.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, index) {
                          final cat = _allFavoriteCategories[index];
                          final selected = workingSelections.contains(cat);

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            selected: selected,
                            selectedTileColor: overlayTheme.selectionFillColor,
                            iconColor: overlayTheme.selectionAccentColor,
                            title: Text(
                              cat,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check,
                                    color: overlayTheme.selectionAccentColor,
                                  )
                                : null,
                            onTap: () {
                              sheetSetState(() {
                                workingSelections = workingSelections.toSet();
                                _mutateDraftCategory(
                                  cat,
                                  selections: workingSelections,
                                );
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(workingSelections.toSet()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Valider',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (validatedSelections != null && mounted) {
      setState(() {
        _draftFavoriteSelections = validatedSelections.toSet();
      });
    }
  }

  Future<void> _openSubcategoryPickerSheet() async {
    var workingSelections = _draftFavoriteSelections.toSet();
    final overlayTheme = context.prestoOverlayTheme;

    final validatedSelections = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (ctx) {
        final selectedCategories =
            workingSelections.where((e) => !e.contains('—')).toList();
        if (selectedCategories.isEmpty) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.35,
              child: const Center(
                child: Text(
                  'Choisis d’abord une catégorie',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final items =
            <({String category, String? subcategory, bool isHeader})>[];
        for (final category in selectedCategories) {
          items.add((category: category, subcategory: null, isHeader: true));
          final subs = _subCategoriesByCategory[category] ?? const <String>[];
          for (final sub in subs) {
            items.add((category: category, subcategory: sub, isHeader: false));
          }
        }

        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final visibleCategories =
                workingSelections.where((e) => !e.contains('—')).toList();
            final items =
                <({String category, String? subcategory, bool isHeader})>[];
            for (final category in visibleCategories) {
              items
                  .add((category: category, subcategory: null, isHeader: true));
              final subs =
                  _subCategoriesByCategory[category] ?? const <String>[];
              for (final sub in subs) {
                items.add(
                    (category: category, subcategory: sub, isHeader: false));
              }
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Text(
                        'Choisir des sous-catégories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          if (item.isHeader) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: 10, bottom: 6),
                              child: Text(
                                item.category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: kPrestoBlue,
                                ),
                              ),
                            );
                          }

                          final sub = item.subcategory!;
                          final label = '${item.category} — $sub';
                          final selected = workingSelections.contains(label);

                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            selected: selected,
                            selectedTileColor: overlayTheme.selectionFillColor,
                            iconColor: overlayTheme.selectionAccentColor,
                            title: Text(
                              sub,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                                    Icons.check,
                                    color: overlayTheme.selectionAccentColor,
                                  )
                                : null,
                            onTap: () {
                              sheetSetState(() {
                                workingSelections = workingSelections.toSet();
                                _mutateDraftSubcategory(
                                  category: item.category,
                                  subcategory: sub,
                                  selections: workingSelections,
                                );
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(workingSelections.toSet()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrestoBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Valider',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (validatedSelections != null && mounted) {
      setState(() {
        _draftFavoriteSelections = validatedSelections.toSet();
      });
    }
  }

  Future<void> _toggleFavoriteSubcategory(User user, String subcategory) async {
    setState(() {
      if (_selectedFavoriteSubcategories.contains(subcategory)) {
        _selectedFavoriteSubcategories.remove(subcategory);
      } else {
        _selectedFavoriteSubcategories.add(subcategory);
      }
    });
    await _saveProfile(user, showSuccess: false);
  }

  Future<void> _signInWithGoogle() async {
    await AccountSocialAuthActions.signInWithGoogle(
      context: context,
      auth: _auth,
      googleAuthService: _googleAuthService,
      trackLogin: _trackLogin,
    );
  }

  Future<void> _signInWithApple() async {
    await AccountSocialAuthActions.signInWithApple(
      context: context,
      auth: _auth,
      trackLogin: _trackLogin,
    );
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    try {
      await NotificationService().detachCurrentDevice();
      await _auth.signOut().timeout(const Duration(seconds: 10));
      SessionState.userId = null;
      sessionState.logOut();
      await CrashlyticsContext.setUserId(null);

      if (!mounted) return;
      showSuccessSnackBar(context, 'Déconnecté');
    } on TimeoutException {
      if (!mounted) return;
      showErrorSnackBar(context, 'La déconnexion a expiré. Réessayez.');
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur de déconnexion : $error');
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  // Ancienne méthode _buildProfile supprimée - remplacée par PrestoPremiumAuthPage pour l'auth

  Widget _buildAccountSectionCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
    bool isExpanded = true,
    VoidCallback? onToggle,
  }) {
    final isCollapsible = onToggle != null;
    final header = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: kPrestoBlue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kPrestoBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16324F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (isCollapsible)
          Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: const Color(0xFF16324F),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrestoBlue.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCollapsible)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(16),
                child: header,
              ),
            )
          else
            header,
          if (!isCollapsible || isExpanded) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildProfile(User user) {
    // ✅ SessionState.userId est maintenant synchronisé automatiquement via authStateChanges()
    // Lier les crash reports à l'utilisateur connecté
    CrashlyticsContext.setUserId(user.uid);

    if (_activeProfileUid != user.uid ||
        (!_profileLoaded && !_profileLoadRequested)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_handleProfileAuthStateChanged(user));
      });
    }

    final pseudo = _profilePseudoController.text.trim();
    final displayName = pseudo.isNotEmpty
        ? pseudo
        : (user.displayName ?? "Utilisateur iliprestō");
    final draftCategoryLabels = _draftFavoriteSelections
        .where((entry) => !entry.contains('—'))
        .toList()
      ..sort();
    final draftSubcategoryLabels = _draftFavoriteSelections
        .where((entry) => entry.contains('—'))
        .toList()
      ..sort();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
          title: const Text(
            "Mon compte iliprestō",
            style: kPrestoAppBarTitleStyle,
          ),
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 150),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white,
                            backgroundImage: user.photoURL != null &&
                                    user.photoURL!.trim().isNotEmpty
                                ? NetworkImage(user.photoURL!.trim())
                                : const AssetImage(
                                    'assets/images/logowebp.webp',
                                  ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Bon retour sur iliprestō',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email ?? "",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ✅ Indicateur de complétude du profil
                          if (_profileLoaded)
                            Builder(
                              builder: (context) {
                                final completeness =
                                    _calculateProfileCompleteness();
                                final missingFields =
                                    _missingRequiredProfileFields();
                                final isComplete = missingFields.isEmpty;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Complétude du profil",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: completeness,
                                          minHeight: 6,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            completeness >= 1.0
                                                ? Colors.green
                                                : completeness >= 0.75
                                                    ? Colors.orange
                                                    : Colors.red,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(completeness * 100).toStringAsFixed(0)}% complet',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Champs requis : ${_requiredProfileFieldLabels.join(', ')}.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isComplete
                                            ? 'Tous les champs requis sont renseignés.'
                                            : 'Champ${missingFields.length > 1 ? 's' : ''} requis manquant${missingFields.length > 1 ? 's' : ''} : ${missingFields.join(', ')}.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isComplete
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          if (_profileLoadError)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber,
                                      size: 14, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Erreur chargement profil',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          const Text(
                            "Tu restes connecté automatiquement.\nTu ne seras déconnecté que si tu appuies sur « Se déconnecter ».",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AccountProfileFormSection(
                      pseudoController: _profilePseudoController,
                      cityController: _profileCityController,
                      phoneController: _profilePhoneController,
                      phoneCountryCode: _profilePhoneCountryCode,
                      isEditing: _isEditingProfile,
                      isSaving: _isSavingProfile,
                      onStartEditing: () {
                        setState(() => _isEditingProfile = true);
                      },
                      onPhoneCountryCodeChanged: (code) {
                        if (!mounted || _profilePhoneCountryCode == code)
                          return;
                        setState(() => _profilePhoneCountryCode = code);
                      },
                      onSave: () {
                        _saveProfile(user);
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildAccountSectionCard(
                      icon: Icons.campaign_outlined,
                      title: 'Gérer mes annonces',
                      description:
                          'Retrouve tes annonces par statut, modifie-les ou supprime-les avec confirmation.',
                      isExpanded: _isPublishedOffersExpanded,
                      onToggle: () {
                        setState(() {
                          _isPublishedOffersExpanded =
                              !_isPublishedOffersExpanded;
                        });
                      },
                      child: RepaintBoundary(
                        child: UserOffersSection(
                          userId: user.uid,
                          showTitle: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAccountSectionCard(
                      icon: Icons.favorite_border_rounded,
                      title: 'Mes annonces favorites',
                      description:
                          'Retrouve les annonces enregistrées pour plus tard.',
                      isExpanded: _isFavoriteOffersExpanded,
                      onToggle: () {
                        setState(() {
                          _isFavoriteOffersExpanded =
                              !_isFavoriteOffersExpanded;
                        });
                      },
                      child: RepaintBoundary(
                        child: FavoriteOffersSection(
                          userId: user.uid,
                          showTitle: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAccountSectionCard(
                      icon: Icons.tune_rounded,
                      title: 'Mes alertes "Nouvelle annonce"',
                      description:
                          'Organise les alertes qui correspondent à tes préférences.',
                      child: RepaintBoundary(
                        child: AccountFavoriteCategoriesSection(
                          categoriesCount: draftCategoryLabels.length,
                          subcategoriesCount: draftSubcategoryLabels.length,
                          selectedCategories: draftCategoryLabels,
                          selectedSubcategories: draftSubcategoryLabels,
                          isSaving: _isSavingProfile,
                          showTitle: false,
                          onOpenCategoryPicker: _openCategoryPickerSheet,
                          onOpenSubcategoryPicker: _openSubcategoryPickerSheet,
                          onApply: () => _applyDraftFavorites(user),
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 28),
                    _buildAdminSpaceEntry(user),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSigningOut ? null : _signOut,
                        icon: _isSigningOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: Text(
                          _isSigningOut ? 'Déconnexion...' : 'Se déconnecter',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }

  Widget _buildAdminSpaceEntry(User user) {
    if (_adminAccessFuture == null || _adminAccessFutureUid != user.uid) {
      _refreshAdminAccessForUser(user.uid);
    }

    return FutureBuilder<AdminAccessState>(
      future: _adminAccessFuture,
      builder: (context, accessSnapshot) {
        final resolvedState = accessSnapshot.data ?? _lastAdminAccessState;

        if (accessSnapshot.hasError) {
          final retryCard = _buildAdminLoadRetryCard(
            user: user,
            title: 'Espace admin indisponible',
            message:
                'Le chargement du profil admin a échoué temporairement. Réessaie pour vérifier l’accès.',
            detail: _adminErrorDetail(accessSnapshot.error),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              retryCard,
              if (resolvedState != null &&
                  _shouldShowAdminDebugCard(user, state: resolvedState))
                _buildAdminDebugCard(user, state: resolvedState),
            ],
          );
        }

        if (accessSnapshot.connectionState == ConnectionState.waiting &&
            resolvedState == null) {
          final loadingCard = _buildAdminLoadingCard();
          if (_shouldShowAdminDebugCard(user)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                loadingCard,
                if (resolvedState != null)
                  _buildAdminDebugCard(user, state: resolvedState),
              ],
            );
          }
          return loadingCard;
        }

        final accessState = resolvedState ?? AdminAccessState.initial();

        if (accessSnapshot.connectionState == ConnectionState.waiting) {
          final loadingCard = _buildAdminLoadingCard();
          if (_shouldShowAdminDebugCard(user, state: accessState)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                loadingCard,
                _buildAdminDebugCard(user, state: accessState),
              ],
            );
          }
          return loadingCard;
        }

        if (!accessState.effectiveIsAdmin) {
          if (_shouldShowAdminDebugCard(user, state: accessState)) {
            return _buildAdminDebugCard(user, state: accessState);
          }
          return const SizedBox.shrink();
        }

        if (_adminShouldUseLocalFallback(accessState)) {
          final fallbackCard = _buildAdminLocalFallbackCard(
            user: user,
            state: accessState,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fallbackCard,
              if (_shouldShowAdminDebugCard(user, state: accessState))
                _buildAdminDebugCard(user, state: accessState),
            ],
          );
        }

        if (_adminCfgFuture == null || _adminCfgFutureUid != user.uid) {
          _refreshAdminConfigForUser(user.uid);
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _adminCfgFuture,
          builder: (context, cfgSnapshot) {
            final cfg = cfgSnapshot.data ?? const <String, dynamic>{};
            final mode = (cfg['mode'] ?? adminAudioRuntimeStore.configuredMode)
                .toString();
            if (cfgSnapshot.hasData) {
              adminAudioRuntimeStore.updateConfiguredMode(mode);
            }

            final configLoaded = cfgSnapshot.hasData;
            final configError = cfgSnapshot.hasError;

            final adminCard = Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kPrestoBlue.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          color: kPrestoBlue.withOpacity(0.95)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Espace admin',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'Verifie',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    configLoaded
                        ? 'Acces admin confirme pour ce profil. Source: ${_adminConfigSourceLabel(accessState)}. Mode serveur actuel: ${_adminModeStatusLabel(mode)}.'
                        : 'Acces admin confirme pour ce profil. La configuration serveur est en cours de chargement.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dernier controle: ${_formatAdminCheckTime(_adminLastCheckedAt)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black45,
                      fontSize: 12,
                    ),
                  ),
                  if (configError) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Config Micro-IA indisponible: ${_adminErrorDetail(cfgSnapshot.error)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (accessState.sourceOfTruth != 'none') ...[
                    const SizedBox(height: 6),
                    Text(
                      'Source droits admin: ${_adminConfigSourceLabel(accessState)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (configLoaded ? kPrestoBlue : Colors.orange)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          configLoaded
                              ? 'Config Micro-IA chargee'
                              : 'Config Micro-IA en attente',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: (configLoaded ? kPrestoBlue : Colors.orange)
                                .withOpacity(0.92),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kPrestoOrange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Pipeline: ${_adminModeStatusLabel(mode)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: kPrestoOrange.withOpacity(0.92),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminSpacePage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text("Ouvrir l'espace admin"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrestoOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (_shouldShowAdminDebugCard(
              user,
              state: accessState,
            )) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  adminCard,
                  _buildAdminDebugCard(user, state: accessState),
                ],
              );
            }
            return adminCard;
          },
        );
      },
    );
  }

  Widget _buildAdminLocalFallbackCard({
    required User user,
    required AdminAccessState state,
    String? detail,
  }) {
    final localSource = _adminLocalSource(state);
    final sourceLabel = localSource.isNotEmpty ? ' via $localSource' : '';
    final fallbackDetail = detail?.trim().isNotEmpty == true
        ? detail!.trim()
        : (state.serverErrorCode != null
            ? _adminStateErrorDetail(state)
            : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings,
                  color: kPrestoBlue.withOpacity(0.95)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Espace admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Mode secours',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_adminFallbackMessage(state)}${sourceLabel.isNotEmpty ? ' Détection locale$sourceLabel.' : ''}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dernier contrôle: ${_formatAdminCheckTime(_adminLastCheckedAt)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
          if (fallbackDetail != null && fallbackDetail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Détail: $fallbackDetail',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _refreshAdminAccessForUser(user.uid, forceRefresh: true);
                      _refreshAdminConfigForUser(user.uid);
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Relancer le contrôle'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminSpacePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text("Ouvrir l'espace admin"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _getSubcategoriesForCategory(String category) {
    final subcats = kCategorySubcategories[category] ?? [];
    return ['', ...subcats];
  }

  List<String> _getAvailableSubcategories() {
    final allSubcats = <String>{};
    for (final cat in _selectedFavoriteCategories) {
      final subcats = kCategorySubcategories[cat] ?? [];
      allSubcats.addAll(subcats);
    }
    return allSubcats.toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.idTokenChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          SessionState.userId = null;
          CrashlyticsContext.setUserId(null);
          return const SignedOutAccountFallback(source: 'account-route');
          /*
          return PrestoPremiumAuthPage(
            onGoogle: () async => await _signInWithGoogle(),
            onApple: () async => await _signInWithApple(),
            onEmailLogin: (email, password) async {
              await _auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            },
            onResetPassword: (email) async {
              await _auth.sendPasswordResetEmail(email: email);
            },
          );
          */
        } else {
          return _buildProfile(user);
        }
      },
    );
  }

}
