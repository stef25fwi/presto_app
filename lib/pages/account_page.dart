
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../app/presto_overlay_theme.dart';
import '../app_core.dart';
import '../constants.dart';
import '../features/account/signed_out_account_fallback.dart';
import '../features/micro_ia/micro_ia_service.dart';
import '../features/subscriptions/subscription_widgets.dart';
import '../models/admin_access_state.dart';
import 'admin_space_loader.dart';
import '../services/admin_access_resolver.dart';
import '../services/ad_placeholder_image_service.dart';
import '../services/email_action_service.dart';
import '../services/firebase_functions_region.dart';
import '../services/notification_service.dart';
import '../services/user_profile_bootstrap_service.dart';
import '../services/user_profile_save_payload.dart';
import '../utils/crashlytics_context.dart';
import '../utils/friendly_snackbar.dart';
import '../widgets/account_notifications_tile.dart';
import '../widgets/account_profile_sections.dart';
import '../services/app_check_bootstrap.dart';
import '../widgets/account_menu_item.dart';
import '../widgets/language_picker_sheet.dart';

import '../app/runtime_stores.dart' show adminAudioRuntimeStore;
import '../app/startup_state.dart'
    show pendingRedirectAuthError, pendingRedirectAuthResult;
import '../app/system_ui_style.dart' show prestoOverlayStyleFor;
import '../services/presto_monitoring.dart' show PrestoMonitoring;
import 'user_offers_section.dart';
import 'fiche_pro_page.dart';
import 'package:presto_app/pages/account/account_security_page.dart';
import 'package:presto_app/pages/account/mes_avis_page.dart';
import 'package:presto_app/pages/account/mes_projets_fiche_page.dart';
import 'package:presto_app/pages/account/mon_entreprise_parcours_page.dart';
import 'package:presto_app/pages/account/verifier_siret_page.dart';
import 'package:presto_app/pages/legal_info_page.dart';
import 'package:presto_app/pages/toolbox_page.dart';
import 'package:presto_app/utils/profile_avatar_resolver.dart';
import 'package:presto_app/services/profile_department_resolver.dart';

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
  final AdminAccessResolver _adminAccessResolver = AdminAccessResolver();

  // Flux conservé pour toute la durée de vie de la page : recréer le stream à
  // chaque build relancerait l'état « en attente » et referait clignoter la
  // bannière des alertes « Nouvelle annonce ».
  final Stream<List<AdPlaceholderImage>> _subscriptionAlertsBannerStream =
      AdPlaceholderImageService.watchAll(
    target: 'subscription_alerts_banner',
  );

  final FirebaseFunctions _functions = prestoFirebaseFunctions;

  Future<void> _trackLogin({String? authMethod, bool isNewUser = false}) async {
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
        name: 'trackUserLogin',
        ms: sw.elapsedMilliseconds,
      );
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
  final _departmentController = TextEditingController();

  // Profil utilisateur
  final TextEditingController _profilePseudoController =
      TextEditingController();
  final TextEditingController _profileCityController = TextEditingController();
  final TextEditingController _profilePhoneController = TextEditingController();
  String _profilePhoneCountryCode = '+33';
  String _profileAccountType = 'Particulier';
  StreamSubscription<User?>? _profileAuthSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileDocSub;
  String? _activeProfileUid;
  String _profileEmail = '';
  String? _profilePhotoUrl;
  DateTime? _profilePhotoUploadedAt;

  Set<String> _favoriteCategories = <String>{};
  Set<String> _selectedFavoriteCategories = <String>{};
  Set<String> _selectedFavoriteSubcategories = <String>{};
  Set<String> _selectedFavoriteDepartements = <String>{};
  Set<String> _draftFavoriteSelections = <String>{};
  bool _profileLoaded = false;
  bool _profileLoadRequested = false;
  bool _isSavingProfile = false;
  bool _isUploadingProfilePhoto = false;
  bool _isSigningOut = false;
  bool _isEditingProfile = false; // ✅ Mode édition du profil
  bool _isProfileSectionExpanded = false;
  bool _isPublishedOffersExpanded = false;
  bool _isFavoriteOffersExpanded = false;
  bool _profileLoadError = false;
  int _profileLoadRetries = 0;
  bool _profileSyncInProgress = false;
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
  Timer? _adminLoadingTimeoutTimer;
  bool _adminLoadingTimedOut = false;

  void _resetAdminAccessState() {
    _adminAccessFuture = null;
    _adminAccessFutureUid = null;
    _lastAdminAccessState = null;
    _adminCfgFuture = null;
    _adminCfgFutureUid = null;
    _adminLastCheckedAt = null;
    _adminLoadingTimeoutTimer?.cancel();
    _adminLoadingTimeoutTimer = null;
    _adminLoadingTimedOut = false;
  }

  bool _shouldShowAdminDebugCard(User user, {AdminAccessState? state}) {
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
    bool returnOnLocalAdminEvidence = false,
  }) {
    _adminAccessFutureUid = uid;
    _adminLoadingTimedOut = false;
    _adminLoadingTimeoutTimer?.cancel();
    _adminLoadingTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _adminAccessFutureUid == uid) {
        setState(() => _adminLoadingTimedOut = true);
      }
    });
    final future = _adminAccessResolver.resolveAdminAccess(
      forceRefresh: forceRefresh,
      returnOnLocalAdminEvidence: returnOnLocalAdminEvidence,
    );
    _adminAccessFuture = future;
    unawaited(
      future.then((state) {
        if (!mounted || _adminAccessFuture != future) {
          return;
        }
        _adminLoadingTimeoutTimer?.cancel();
        setState(() {
          _lastAdminAccessState = state;
          _adminLastCheckedAt = state.serverCheckedAt ?? _adminLastCheckedAt;
          _adminLoadingTimedOut = false;
        });
        if (state.effectiveIsAdmin) {
          unawaited(adminAudioRuntimeStore.enableCloudSync());
        }
        if (returnOnLocalAdminEvidence && !state.serverCheckAttempted) {
          unawaited(_refreshAdminAccessServerForUser(uid));
        }
      }).catchError((Object error, StackTrace stackTrace) {
        _adminLoadingTimeoutTimer?.cancel();
        debugPrint('[AdminProfile] admin access resolution failed: $error');
      }),
    );
  }

  Future<void> _refreshAdminAccessServerForUser(String uid) async {
    try {
      final state = await _adminAccessResolver.resolveAdminAccess(
        forceRefresh: true,
      );
      if (!mounted || _adminAccessFutureUid != uid) return;
      setState(() {
        _lastAdminAccessState = state;
        _adminLastCheckedAt = state.serverCheckedAt ?? _adminLastCheckedAt;
      });
      if (state.effectiveIsAdmin) {
        unawaited(adminAudioRuntimeStore.enableCloudSync());
      }
    } catch (error) {
      debugPrint('[AdminProfile] background server admin check failed: $error');
    }
  }

  bool _isProfileSyncExpired(Object? error) {
    if (error is UserProfileBootstrapException) {
      return error.isTimeout;
    }
    if (error is TimeoutException) {
      return true;
    }
    final message = error?.toString().toLowerCase() ?? '';
    return message.contains('timeout') ||
        message.contains('deadline-exceeded') ||
        message.contains('profile-access-timeout');
  }

  Future<bool> _suppressProfileSyncSnackBarWhenAdminConfirmed(
    Object error, {
    required String trigger,
  }) async {
    var state = _lastAdminAccessState;
    if (state?.hasConfirmedAdminAccess != true) {
      try {
        state = await _adminAccessResolver.resolveAdminAccess();
        if (mounted) {
          setState(() {
            _lastAdminAccessState = state;
            _adminLastCheckedAt = state?.serverCheckedAt ?? _adminLastCheckedAt;
          });
        }
      } catch (resolverError) {
        debugPrint(
          '[ProfileSync][AdminGuard] resolver failed trigger=$trigger error=$resolverError',
        );
      }
    }

    final finalCanAccessAdmin = state?.hasConfirmedAdminAccess == true;
    final reason = finalCanAccessAdmin
        ? 'admin-confirmed-by-${state!.consolidatedSourceOfTruth}'
        : 'no-admin-source-confirmed';
    debugPrint(
      '[ProfileSync][AdminGuard] trigger=$trigger '
      'profileSyncExpired=${_isProfileSyncExpired(error)} '
      'serverIsAdmin=${state?.serverIsAdmin} '
      'tokenHasAdmin=${state?.tokenHasAdmin ?? false} '
      'profileHasAdmin=${state?.profileHasAdmin ?? false} '
      'adminDocHasAdmin=${state?.adminDocHasAdmin ?? false} '
      'finalCanAccessAdmin=$finalCanAccessAdmin '
      'reason=$reason',
    );
    if (finalCanAccessAdmin) {
      unawaited(adminAudioRuntimeStore.enableCloudSync());
    }
    return finalCanAccessAdmin;
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
      await MicroIaService.prepareSecureCallableContext(
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
      );
      HttpsCallableResult<dynamic> res;
      try {
        res = await callable.call<dynamic>({});
      } on FirebaseFunctionsException catch (e) {
        if (e.code != 'unauthenticated' && e.code != 'permission-denied') {
          rethrow;
        }
        await MicroIaService.prepareSecureCallableContext(
          forceRefreshToken: true,
          forceRefreshAppCheckToken: true,
        );
        res = await callable.call<dynamic>({});
      }
      sw.stop();
      PrestoMonitoring.I.trackFunctionsCall(
        name: 'adminGetMicroIaConfig',
        ms: sw.elapsedMilliseconds,
      );
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

  Widget _buildAdminDebugCard(User user, {required AdminAccessState state}) {
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
          const SizedBox(height: 12),
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
              fontFamily: 'Inter',
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
        color: kPrestoBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrestoBlue.withValues(alpha: 0.18)),
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
                    MaterialPageRoute(builder: (_) => const AdminSpaceLoader()),
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
      'Peinture',
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
    _profileCityController.addListener(_syncProfileDepartmentFromLocation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncProfileDepartmentFromLocation();
    });
    unawaited(adminAudioRuntimeStore.ensureInitialized());
    // _isLoginMode = !widget.startInSignup; // Plus utilisé avec PrestoPremiumAuthPage
    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });
    _profilePseudoController.addListener(_handleProfileCompletenessChanged);
    _profileCityController.addListener(_handleProfileCompletenessChanged);
    _profilePhoneController.addListener(_handleProfileCompletenessChanged);
    _profileAuthSub = _auth.authStateChanges().listen((user) {
      if (!mounted) return;
      unawaited(_handleProfileAuthStateChanged(user));
    });

    // Sur Web, vérifie si l'utilisateur revient d'un redirect OAuth fédéré.
    if (kIsWeb) {
      _checkFederatedRedirectResult();
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

  void _resetProfileState({bool clearControllers = true}) {
    _activeProfileUid = null;
    _profileLoaded = false;
    _profileLoadRequested = false;
    _profileLoadError = false;
    _profileLoadRetries = 0;
    _lastMissingRequiredCount = -1;
    _isEditingProfile = false;
    _profilePhoneCountryCode = '+33';
    _profileAccountType = 'Particulier';
    _profileEmail = '';
    _profilePhotoUrl = null;
    _profileSyncInProgress = false;
    _favoriteCategories = <String>{};
    _selectedFavoriteCategories = <String>{};
    _selectedFavoriteSubcategories = <String>{};
    _selectedFavoriteDepartements = <String>{};
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
      await _profileDocSub?.cancel();
      _profileDocSub = null;
      setState(() {
        _resetProfileState();
      });
      return;
    }

    SessionState.userId = user.uid;

    await _startInstantProfileHydration(user);
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
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: FirebaseAuth.instance.currentUser,
        forceRefreshToken: false,
        forceRefreshAppCheckToken: false,
      );
      return await userRef
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        // Token may be stale — force one refresh and retry.
        debugPrint(
          '[Profile] Auth error, forcing token refresh: ${error.code}',
        );
        await FirebaseAuth.instance.currentUser
            ?.getIdToken(true)
            .timeout(const Duration(seconds: 8));
        return await userRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
      }
      // Network or quota issue — serve from cache.
      debugPrint('[Profile] Server unavailable (${error.code}), using cache');
      return userRef
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('[Profile] Fallback cache: $error');
      return userRef
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 3));
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
      _fetchCachedUserProfileDocument(String uid) async {
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(milliseconds: 800));
    } catch (error) {
      debugPrint('[Profile] Cache profil indisponible: $error');
      return null;
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

  String _inferPhoneCountryCodeFromCity(String cityValue) {
    final match = RegExp(
      r'\b(97\d{3}|98\d{3}|\d{5})\b',
    ).firstMatch(cityValue.trim());
    if (match == null) return '+33';
    final postal = match.group(1)!;
    final dept = (postal.startsWith('97') || postal.startsWith('98'))
        ? postal.substring(0, 3)
        : postal.substring(0, 2);
    if (dept == '971') return '+590'; // Guadeloupe
    if (dept == '972') return '+596'; // Martinique
    if (dept == '973') return '+594'; // Guyane
    if (dept == '974' || dept == '976') return '+262'; // La Réunion / Mayotte
    if (dept == '987') return '+689'; // Polynésie française
    return '+33';
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

  String _deriveImmediatePseudo(User user) {
    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email?.trim() ?? '';
    if (email.contains('@')) {
      return email.split('@').first.trim();
    }

    return 'Utilisateur';
  }

  bool _canHydrateProfileField(TextEditingController controller) {
    if (!_isEditingProfile) {
      return true;
    }
    return controller.text.trim().isEmpty;
  }

  void _applyImmediateAuthProfile(User user) {
    final nextEmail = user.email?.trim() ?? '';
    if (nextEmail.isNotEmpty) {
      _profileEmail = nextEmail;
    }

    final nextPhotoUrl = customProfilePhotoUrl(user.photoURL);

    if (nextPhotoUrl != null) {
      // Une photo réellement choisie par l'utilisateur reste autorisée.
      _profilePhotoUrl = nextPhotoUrl;
    } else if (isAutomaticGoogleProfilePhoto(_profilePhotoUrl)) {
      // Une ancienne photo Google éventuellement chargée est neutralisée.
      _profilePhotoUrl = '';
    }

    final pseudo = _deriveImmediatePseudo(user);
    if (pseudo.isNotEmpty &&
        _canHydrateProfileField(_profilePseudoController)) {
      _profilePseudoController.text = pseudo;
    }

    final authPhone = user.phoneNumber?.trim() ?? '';
    if (authPhone.isNotEmpty &&
        _canHydrateProfileField(_profilePhoneController)) {
      _applyLoadedProfilePhone(authPhone);
    }
  }

  String _firstNonEmptyProfilePhoto(Map<String, dynamic>? data) {
    return _firstNonEmptyProfileValue(
      data,
      const [
        'photoUrl',
        'photoURL',
        'profilePhotoUrl',
        'avatarUrl',
        'avatarURL',
        'imageUrl',
      ],
      fallbackValues: <String>[_profilePhotoUrl ?? ''],
    );
  }

  String _firstStoredProfilePhotoPath(Map<String, dynamic>? data) {
    return _firstNonEmptyProfileValue(data, const ['profilePhotoPath']);
  }

  bool _isResolvableStorageProfilePhoto(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('gs://') || trimmed.startsWith('profilePhotos/');
  }

  Future<void> _hydrateProfilePhotoFromStorage(
    User user,
    Map<String, dynamic> data,
  ) async {
    final storedPath = _firstStoredProfilePhotoPath(data);
    final currentPhotoValue = _firstNonEmptyProfilePhoto(data);

    if (storedPath.isEmpty &&
        !_isResolvableStorageProfilePhoto(currentPhotoValue)) {
      return;
    }

    try {
      final ref = storedPath.isNotEmpty
          ? FirebaseStorage.instance.ref().child(storedPath)
          : FirebaseStorage.instance.refFromURL(currentPhotoValue.trim());
      final downloadUrl = await ref.getDownloadURL().timeout(
            const Duration(seconds: 12),
          );
      final normalizedUrl = downloadUrl.trim();
      if (normalizedUrl.isEmpty || !mounted || _activeProfileUid != user.uid) {
        return;
      }

      setState(() => _profilePhotoUrl = normalizedUrl);

      final profilePhotoPayload = <String, dynamic>{
        'photoUrl': normalizedUrl,
        'photoURL': normalizedUrl,
        'profilePhotoUrl': normalizedUrl,
        'avatarUrl': normalizedUrl,
        'imageUrl': normalizedUrl,
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profilePhotoPayload, SetOptions(merge: true));
    } catch (error) {
      debugPrint(
        '[ProfilePhoto] storage hydration failed uid=${user.uid}: $error',
      );
    }
  }

  String _safeProfilePhotoName(String name, String fallback) {
    final cleaned = name.trim().isEmpty ? fallback : name.trim();
    final sanitized = cleaned
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (sanitized.isNotEmpty) return sanitized;
    return fallback;
  }

  String _profilePhotoContentType(String name, String fallback) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.gif')) return 'image/gif';
    return fallback;
  }

  String _normalizedProfilePhotoContentType(XFile picked, String fileName) {
    final pickedMimeType = picked.mimeType?.trim().toLowerCase() ?? '';
    if (pickedMimeType.startsWith('image/')) {
      return pickedMimeType;
    }
    return _profilePhotoContentType(fileName, 'image/jpeg');
  }

  bool _isProfilePhotoUploadAuthFailure(FirebaseException error) {
    return error.code == 'permission-denied' ||
        error.code == 'unauthorized' ||
        error.code == 'unauthenticated';
  }

  Future<void> _pickAndUploadProfilePhoto(User user) async {
    if (_isUploadingProfilePhoto) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1200,
    );
    if (picked == null) return;

    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (error) {
      debugPrint('[ProfilePhoto] read failed: $error');
      if (!mounted) return;
      showErrorSnackBar(context, 'Cette photo ne peut pas être lue.');
      return;
    }

    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      if (!mounted) return;
      showErrorSnackBar(context, 'La photo dépasse 10 Mo.');
      return;
    }

    setState(() => _isUploadingProfilePhoto = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = _safeProfilePhotoName(picked.name, 'profil.jpg');
      final path = 'profilePhotos/${user.uid}/${timestamp}_$fileName';
      final contentType = _normalizedProfilePhotoContentType(picked, fileName);
      final ref = FirebaseStorage.instance.ref().child(path);

      await user.getIdToken(false).timeout(const Duration(seconds: 12));
      try {
        await ref
            .putData(bytes, SettableMetadata(contentType: contentType))
            .timeout(const Duration(seconds: 30));
      } on FirebaseException catch (error) {
        if (!_isProfilePhotoUploadAuthFailure(error)) rethrow;
        await user.getIdToken(true).timeout(const Duration(seconds: 12));
        await ref
            .putData(bytes, SettableMetadata(contentType: contentType))
            .timeout(const Duration(seconds: 30));
      }
      final downloadUrl = await ref.getDownloadURL();
      if (downloadUrl.trim().isEmpty) {
        throw StateError('URL photo profil vide');
      }

      final profilePhotoPayload = <String, dynamic>{
        'photoUrl': downloadUrl,
        'photoURL': downloadUrl,
        'profilePhotoUrl': downloadUrl,
        'avatarUrl': downloadUrl,
        'imageUrl': downloadUrl,
        'profilePhotoPath': path,
        'profilePhotoMimeType': contentType,
        'profilePhotoUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: false,
        forceRefreshAppCheckToken: false,
      );
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(profilePhotoPayload, SetOptions(merge: true))
            .timeout(const Duration(seconds: 12));
      } on FirebaseException catch (error) {
        if (!_isProfilePhotoUploadAuthFailure(error)) rethrow;
        await UserProfileBootstrapService.prepareProfileFirestoreAccess(
          user: user,
          forceRefreshToken: true,
          forceRefreshAppCheckToken: true,
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(profilePhotoPayload, SetOptions(merge: true))
            .timeout(const Duration(seconds: 12));
      }

      try {
        await user
            .updatePhotoURL(downloadUrl)
            .timeout(const Duration(seconds: 5));
        await user.reload().timeout(const Duration(seconds: 5));
      } catch (error) {
        debugPrint('[ProfilePhoto] auth photoURL sync failed: $error');
      }

      if (!mounted || _activeProfileUid != user.uid) return;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _profilePhotoUploadedAt = DateTime.now();
      setState(() => _profilePhotoUrl = downloadUrl);
      showSuccessSnackBar(context, 'Photo de profil mise à jour');
    } on FirebaseException catch (error) {
      debugPrint(
        '[ProfilePhoto] Firebase error code=${error.code} message=${error.message}',
      );
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error.code == 'permission-denied'
            ? 'Upload refusé. Vérifiez votre connexion et réessayez.'
            : 'La photo de profil n’a pas pu être envoyée.',
      );
    } catch (error) {
      debugPrint('[ProfilePhoto] upload failed: $error');
      if (!mounted) return;
      showErrorSnackBar(context, 'La photo de profil n’a pas pu être envoyée.');
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePhoto = false);
      }
    }
  }

  Future<void> _startInstantProfileHydration(User user) async {
    final uid = user.uid;
    final isSameUser = _activeProfileUid == uid;
    if (isSameUser && _profileDocSub != null) {
      if (!mounted) return;
      setState(() {
        _applyImmediateAuthProfile(user);
        _refreshAdminAccessForUser(uid);
      });
      return;
    }

    final oldSub = _profileDocSub;
    _profileDocSub = null;
    await oldSub?.cancel();
    if (!mounted) return;

    setState(() {
      _resetProfileState();
      _activeProfileUid = uid;
      _profileLoadRequested = true;
      _profileLoaded = true;
      _profileSyncInProgress = true;
      _applyImmediateAuthProfile(user);
      _lastMissingRequiredCount = _missingRequiredProfileFields().length;
      _refreshAdminAccessForUser(uid, forceRefresh: true);
    });

    unawaited(() async {
      try {
        await UserProfileBootstrapService.ensureUserDocument(
          user: user,
          authMethod: 'session_restore',
        );
      } on FirebaseException catch (error) {
        debugPrint(
          '[AuthBootstrap] account session restore Firestore failed '
          'uid=${user.uid} path=users/${user.uid} '
          'code=${error.code} message=${error.message}',
        );
      } catch (error) {
        debugPrint(
          '[AuthBootstrap] account session restore failed '
          'uid=${user.uid} path=users/${user.uid} error=$error',
        );
      }
    }());

    unawaited(
      UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: false,
        forceRefreshAppCheckToken: false,
      ).catchError((Object error) {
        debugPrint('[Profile] prepareProfileFirestoreAccess ignored: $error');
        return null;
      }),
    );

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    _profileDocSub = userRef.snapshots(includeMetadataChanges: true).listen(
      (snapshot) {
        if (!mounted || _activeProfileUid != uid) return;
        if (snapshot.metadata.hasPendingWrites) return;

        final previousPseudo = _profilePseudoController.text.trim();
        final previousCity = _profileCityController.text.trim();
        final previousPhoneCountryCode = _profilePhoneCountryCode;
        final previousPhone = _profilePhoneController.text.trim();
        final previousFavoriteCategories = _favoriteCategories.toSet();
        final previousSelectedFavoriteCategories =
            _selectedFavoriteCategories.toSet();
        final previousSelectedFavoriteSubcategories =
            _selectedFavoriteSubcategories.toSet();
        final previousDraftFavoriteSelections =
            _draftFavoriteSelections.toSet();

        final data = snapshot.data();
        var hydratedPhotoUrl = '';

        setState(() {
          _applyImmediateAuthProfile(user);
          if (data != null) {
            _applyUserProfileDocument(
              user,
              data: data,
              previousPseudo: previousPseudo,
              previousCity: previousCity,
              previousPhoneCountryCode: previousPhoneCountryCode,
              previousPhone: previousPhone,
              previousFavoriteCategories: previousFavoriteCategories,
              previousSelectedFavoriteCategories:
                  previousSelectedFavoriteCategories,
              previousSelectedFavoriteSubcategories:
                  previousSelectedFavoriteSubcategories,
              previousDraftFavoriteSelections: previousDraftFavoriteSelections,
            );
            final hydratedEmail = _firstNonEmptyProfileValue(
              data,
              const ['email'],
              fallbackValues: <String>[_profileEmail, user.email ?? ''],
            );
            if (hydratedEmail.isNotEmpty) {
              _profileEmail = hydratedEmail;
            }
            hydratedPhotoUrl = _firstNonEmptyProfilePhoto(data);
            final photoUploadedRecently = _profilePhotoUploadedAt != null &&
                DateTime.now().difference(_profilePhotoUploadedAt!) <
                    const Duration(seconds: 10);
            if (hydratedPhotoUrl.isNotEmpty && !photoUploadedRecently) {
              _profilePhotoUrl = hydratedPhotoUrl;
            }
          }
          _profileLoadError = false;
          _profileLoaded = true;
          _profileLoadRequested = true;
          _profileSyncInProgress = false;
          _lastMissingRequiredCount = _missingRequiredProfileFields().length;
        });

        if (data != null &&
            (hydratedPhotoUrl.isEmpty ||
                _isResolvableStorageProfilePhoto(hydratedPhotoUrl))) {
          unawaited(_hydrateProfilePhotoFromStorage(user, data));
        }
      },
      onError: (Object error) {
        if (!mounted || _activeProfileUid != uid) {
          return;
        }
        debugPrint('[Profile] snapshot users/$uid failed: $error');
        setState(() {
          _profileLoadError = true;
          _profileLoaded = true;
          _profileLoadRequested = true;
          _profileSyncInProgress = false;
        });
      },
    );
  }

  void _applyUserProfileDocument(
    User user, {
    Map<String, dynamic>? data,
    required String previousPseudo,
    required String previousCity,
    required String previousPhoneCountryCode,
    required String previousPhone,
    required Set<String> previousFavoriteCategories,
    required Set<String> previousSelectedFavoriteCategories,
    required Set<String> previousSelectedFavoriteSubcategories,
    required Set<String> previousDraftFavoriteSelections,
  }) {
    if (data != null) {
      final nextPseudo = _firstNonEmptyProfileValue(
        data,
        const [
          'pseudo',
          'displayName',
          'userName',
          'user_name',
          'name',
          'fullName',
        ],
        fallbackValues: <String>[user.displayName ?? '', previousPseudo],
      );
      if (_canHydrateProfileField(_profilePseudoController)) {
        _profilePseudoController.text = nextPseudo;
      }

      final nextCity = _firstNonEmptyProfileValue(
        data,
        const [
          'city',
          'ville',
          'commune',
          'location',
          'serviceArea',
          'service_area',
        ],
        fallbackValues: <String>[previousCity],
      );
      if (_canHydrateProfileField(_profileCityController)) {
        _profileCityController.text = nextCity;
        _syncProfileDepartmentFromLocation();
      }

      final loadedPhone = _firstNonEmptyProfileValue(
        data,
        const ['phone', 'telephone', 'phoneNumber', 'phone_number'],
        fallbackValues: <String>[user.phoneNumber ?? ''],
      );
      if (loadedPhone.isNotEmpty &&
          _canHydrateProfileField(_profilePhoneController)) {
        _applyLoadedProfilePhone(loadedPhone);
      } else if (previousPhone.isNotEmpty &&
          _profilePhoneController.text.trim().isEmpty) {
        _profilePhoneCountryCode = previousPhoneCountryCode;
        _profilePhoneController.text = previousPhone;
      } else {
        if (_profilePhoneController.text.trim().isEmpty) {
          _applyLoadedProfilePhone('');
          final inferred = _inferPhoneCountryCodeFromCity(
            _profileCityController.text,
          );
          if (inferred != '+33') {
            _profilePhoneCountryCode = inferred;
          }
        }
      }

      final favs = (data['favoriteCategories'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final hasFavoriteCategoriesKey = data.containsKey('favoriteCategories');
      _favoriteCategories =
          hasFavoriteCategoriesKey ? favs.toSet() : previousFavoriteCategories;
      _draftFavoriteSelections = hasFavoriteCategoriesKey
          ? _favoriteCategories.toSet()
          : previousDraftFavoriteSelections;
      final selectedCats =
          (data['selectedFavoriteCategories'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
      final hasSelectedFavoriteCategoriesKey = data.containsKey(
        'selectedFavoriteCategories',
      );
      _selectedFavoriteCategories = hasSelectedFavoriteCategoriesKey
          ? selectedCats.toSet()
          : previousSelectedFavoriteCategories;
      final selectedSubcats =
          (data['selectedFavoriteSubcategories'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
      final hasSelectedFavoriteSubcategoriesKey = data.containsKey(
        'selectedFavoriteSubcategories',
      );
      _selectedFavoriteSubcategories = hasSelectedFavoriteSubcategoriesKey
          ? selectedSubcats.toSet()
          : previousSelectedFavoriteSubcategories;
      if (data.containsKey('selectedFavoriteDepartements')) {
        _selectedFavoriteDepartements =
            (data['selectedFavoriteDepartements'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toSet();
      }

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

      final loadedAccountType = _firstNonEmptyProfileValue(
        data,
        const ['accountType'],
        fallbackValues: <String>[_profileAccountType],
      );
      _profileAccountType =
          loadedAccountType.isNotEmpty ? loadedAccountType : 'Particulier';
    } else {
      if (_canHydrateProfileField(_profilePseudoController)) {
        _profilePseudoController.text =
            user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : previousPseudo;
      }
      if (_canHydrateProfileField(_profileCityController)) {
        _profileCityController.text = previousCity;
      }
      if (previousPhone.isNotEmpty) {
        if (_canHydrateProfileField(_profilePhoneController)) {
          _profilePhoneCountryCode = previousPhoneCountryCode;
          _profilePhoneController.text = previousPhone;
        }
      } else {
        final inferred = _inferPhoneCountryCodeFromCity(
          _profileCityController.text,
        );
        if (inferred != '+33') {
          _profilePhoneCountryCode = inferred;
        }
      }
      _profileAccountType = 'Particulier';
      _favoriteCategories = previousFavoriteCategories;
      _selectedFavoriteCategories = previousSelectedFavoriteCategories;
      _selectedFavoriteSubcategories = previousSelectedFavoriteSubcategories;
      _draftFavoriteSelections = previousDraftFavoriteSelections;
    }

    _isEditingProfile = !_hasProfileValuesInMemory();
    _profileLoadError = false;
    _profileLoadRetries = 0;
  }

  Future<void> _checkFederatedRedirectResult() async {
    final savedResult = pendingRedirectAuthResult;
    final savedError = pendingRedirectAuthError;
    pendingRedirectAuthResult = null;
    pendingRedirectAuthError = null;

    try {
      // Récupère d'abord le résultat capturé tôt dans main.dart pour éviter
      // la course contre la consommation interne du SDK Firebase. Si rien
      // n'a été capturé (cas d'un mount tardif après refresh manuel), on
      // retombe sur l'API live.
      UserCredential? result = savedResult;
      if (result == null && savedError == null) {
        result = await _auth.getRedirectResult();
      } else if (savedError != null && result == null) {
        // Propager l'erreur capturée tôt comme si on venait de l'avoir.
        final captured = savedError;
        if (captured is FirebaseAuthException) {
          throw captured;
        }
        throw captured;
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
        Object? bootstrapFailure;
        try {
          await UserProfileBootstrapService.ensureUserDocument(
            user: result.user!,
            authMethod: authMethod,
            isNewUserHint: isNew,
          );
        } catch (bootstrapError) {
          bootstrapFailure = bootstrapError;
          debugPrint('[OAuth Redirect] Bootstrap error: $bootstrapError');
        }
        try {
          await _trackLogin(authMethod: authMethod, isNewUser: isNew);
        } catch (error) {
          debugPrint('[OAuth Redirect] Tracking error: $error');
        }
        if (!mounted) return;
        if (bootstrapFailure != null) {
          debugPrint(
            '[OAuth Redirect] auth sync failed but user is connected '
            'uid=${result.user!.uid} error=$bootstrapFailure',
          );
        }
        showSuccessSnackBar(context, 'Connecté avec $providerLabel');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = 'Erreur de connexion externe';
      var shouldShow = true;
      if (e.code == 'unauthorized-domain') {
        msg =
            "Domaine non autorisé. Ajoute ce domaine dans Firebase Console → Authentication → Authorized domains.";
      } else if (e.code == 'operation-not-allowed') {
        msg =
            'Fournisseur externe non activé. Vérifie Firebase Authentication → Sign-in method.';
      } else if (e.code != 'invalid-credential' && e.code != 'no-auth-event') {
        msg = 'Erreur externe : ${e.message ?? e.code}';
      } else {
        shouldShow = false;
      }

      if (shouldShow) {
        showErrorSnackBar(context, msg);
      }
    } catch (e) {
      debugPrint('[OAuth Redirect] Error checking result: $e');
    }
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _adminLoadingTimeoutTimer?.cancel();
    _profileAuthSub?.cancel();
    _profileDocSub?.cancel();
    _profilePseudoController.removeListener(_handleProfileCompletenessChanged);
    _profileCityController.removeListener(_handleProfileCompletenessChanged);
    _profilePhoneController.removeListener(_handleProfileCompletenessChanged);
    _profilePseudoController.dispose();
    _profileCityController.dispose();
    _profilePhoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _validateProfile() {
    final pseudo = _profilePseudoController.text.trim();
    final city = _profileCityController.text.trim();
    final departmentCode = ProfileDepartmentResolver.resolveDepartmentCode(
      city: city,
    );
    final departmentLabel = departmentCode == null
        ? ''
        : ProfileDepartmentResolver.departmentDisplayName(departmentCode);
    if (_departmentController.text != departmentLabel) {
      _departmentController.text = departmentLabel;
    }
    final phone = _profilePhoneController.text.trim();
    final normalizedPhone = _normalizeProfilePhoneForSave(
      _profilePhoneCountryCode,
      phone,
    );

    // Validation pseudo
    if (pseudo.isEmpty) {
      showErrorSnackBar(context, "Le pseudo est obligatoire");
      return false;
    }
    if (pseudo.length < 2) {
      showErrorSnackBar(
        context,
        "Le pseudo doit contenir au moins 2 caractères",
      );
      return false;
    }
    if (pseudo.length > 50) {
      showErrorSnackBar(
        context,
        "Le pseudo ne doit pas dépasser 50 caractères",
      );
      return false;
    }
    if (!RegExp(
      r'^[a-zA-Z0-9àâäæéèêëïîôùûüœçÀÂÄÆÉÈÊËÏÎÔÙÛÜŒÇ\s\-_\.]+$',
    ).hasMatch(pseudo)) {
      showErrorSnackBar(
        context,
        "Le pseudo ne peut contenir que des lettres, chiffres et caractères spéciaux (-, _, .)",
      );
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
        context,
        "Le numéro de téléphone doit contenir 10-15 chiffres",
      );
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
    return UserProfileSavePayload.calculateCompleteness(
      displayName: _profilePseudoController.text,
      city: _profileCityController.text,
      phone: _profilePhoneController.text,
    );
  }

  Widget _buildProfileCompletenessBanner() {
    final completeness = _calculateProfileCompleteness().clamp(0.0, 1.0);
    final percent = (completeness * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Complétude du profil',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16324F),
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: kPrestoBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completeness,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(kPrestoBlue),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _saveProfile(User user, {bool showSuccess = true}) async {
    if (!mounted) return false;

    if (!_validateProfile()) {
      return false;
    }

    setState(() => _isSavingProfile = true);
    try {
      final pseudo = _profilePseudoController.text.trim();
      final city = _profileCityController.text.trim();

      final departmentCode = ProfileDepartmentResolver.resolveDepartmentCode(
        city: city,
      );

      final departmentLabel = departmentCode == null
          ? ''
          : ProfileDepartmentResolver.departmentDisplayName(departmentCode);

      _departmentController.text = departmentLabel;
      final phone = _profilePhoneController.text.trim();
      final normalizedPhone = _normalizeProfilePhoneForSave(
        _profilePhoneCountryCode,
        phone,
      );

      final profileData = UserProfileSavePayload.build(
        uid: user.uid,
        email: user.email,
        displayName: pseudo,
        accountType: _profileAccountType,
        phone: normalizedPhone,
        city: city,
        selectedFavoriteCategories: _selectedFavoriteCategories.toList(),
        selectedFavoriteSubcategories: _selectedFavoriteSubcategories.toList(),
        selectedFavoriteDepartements: _selectedFavoriteDepartements.toList(),
      );

      profileData['departmentCode'] = departmentCode;
      profileData['department'] = departmentLabel;

      // Rafraîchir le token App Check avant l'écriture (non bloquant)
      try {
        await refreshAppCheckToken(reason: 'profile-save');
      } catch (_) {}

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      debugPrint('[ProfileSave] write path=users/${user.uid}');
      await userRef
          .set(profileData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      // Write succeeded — exit edit mode and notify user immediately.
      if (mounted) {
        setState(() => _isEditingProfile = false);
        if (showSuccess) {
          showSuccessSnackBar(context, "Profil enregistré");
        }
      }

      // Background: sync Auth displayName then refresh local profile data.
      unawaited(_postSaveBackgroundSync(user, pseudo));

      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        '[ProfileSave] Firestore error path=users/${user.uid} code=${e.code} message=${e.message}',
      );
      if (mounted) {
        String errorMsg = 'Erreur lors de la sauvegarde du profil';
        if (e.code == 'permission-denied') {
          errorMsg =
              'Firestore a refusé l\'écriture users/${user.uid}: ${e.message ?? e.code}';
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
      debugPrint('[ProfileSave] Timeout path=users/${user.uid}');
      if (mounted) {
        showErrorSnackBar(
          context,
          'Délai d\'attente dépassé. Vérifiez votre connexion',
        );
      }
      return false;
    } catch (e) {
      debugPrint('[ProfileSave] Error path=users/${user.uid}: $e');
      if (mounted) {
        showErrorSnackBar(
          context,
          'Erreur lors de la sauvegarde du profil: $e',
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _postSaveBackgroundSync(User user, String pseudo) async {
    // Update Auth display name (best effort).
    if (pseudo.isNotEmpty) {
      try {
        await user
            .updateDisplayName(pseudo)
            .timeout(const Duration(seconds: 5));
        await user.reload().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[ProfileSave] displayName update failed (ignored): $e');
      }
    }

    final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
    if (mounted && _activeProfileUid == refreshedUser.uid) {
      setState(() {
        _applyImmediateAuthProfile(refreshedUser);
      });
    }

    // Send email verification if not yet verified (best effort).
    if (!(refreshedUser.emailVerified) && refreshedUser.email != null) {
      try {
        await EmailActionService.requestEmailVerificationEmail();
      } catch (_) {}
    }
  }

  void _mutateDraftCategory(String category, {Set<String>? selections}) {
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
    final previousFavoriteCategories = _favoriteCategories.toSet();
    final previousSelectedFavoriteCategories =
        _selectedFavoriteCategories.toSet();
    final previousSelectedFavoriteSubcategories =
        _selectedFavoriteSubcategories.toSet();
    final previousSelectedFavoriteDepartements =
        _selectedFavoriteDepartements.toSet();

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
    } else {
      setState(() {
        _favoriteCategories = previousFavoriteCategories;
        _selectedFavoriteCategories = previousSelectedFavoriteCategories;
        _selectedFavoriteSubcategories = previousSelectedFavoriteSubcategories;
        _selectedFavoriteDepartements = previousSelectedFavoriteDepartements;
      });
    }
  }

  Future<void> _openDeptPicker() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final draft = Set<String>.from(_selectedFavoriteDepartements);
        var search = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final entries = kDepartments.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));

            final query = search.trim().toLowerCase();
            final visibleEntries = query.isEmpty
                ? entries
                : entries.where((entry) {
                    final code = entry.key.toLowerCase();
                    final label = entry.value.toLowerCase();
                    return code.contains(query) || label.contains(query);
                  }).toList();

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Choisir des départements',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: kPrestoBlue,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(draft.clear);
                          },
                          child: const Text('Tout effacer'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher un département...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kPrestoBlue,
                            width: 1.4,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) {
                        setModalState(() => search = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: visibleEntries.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFE5E7EB)),
                        itemBuilder: (context, index) {
                          final entry = visibleEntries[index];
                          final code = entry.key;
                          final label = entry.value;
                          final checked = draft.contains(code);

                          return CheckboxListTile(
                            value: checked,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: kPrestoBlue,
                            title: Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(code),
                            onChanged: (_) {
                              setModalState(() {
                                if (checked) {
                                  draft.remove(code);
                                } else {
                                  draft.add(code);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: kPrestoOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(Set<String>.from(draft)),
                            child: const Text('Valider'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _selectedFavoriteDepartements = result);
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
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                        itemCount: _allFavoriteCategories.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, index) {
                          final cat = _allFavoriteCategories[index];
                          final selected = workingSelections.contains(cat);

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
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
              items.add((
                category: category,
                subcategory: null,
                isHeader: true,
              ));
              final subs =
                  _subCategoriesByCategory[category] ?? const <String>[];
              for (final sub in subs) {
                items.add((
                  category: category,
                  subcategory: sub,
                  isHeader: false,
                ));
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
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          if (item.isHeader) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                                bottom: 6,
                              ),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
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

  Widget _buildAccountSectionCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
    Widget? alwaysVisibleChild,
    bool isExpanded = true,
    VoidCallback? onToggle,
  }) {
    final isCollapsible = onToggle != null;
    final header = Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kPrestoBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kPrestoBlue, size: 20),
        ),
        const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB8BEC7), width: 2),
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
          if (alwaysVisibleChild != null) ...[
            const SizedBox(height: 10),
            alwaysVisibleChild,
          ],
          if (!isCollapsible || isExpanded) ...[
            const SizedBox(height: 10),
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

    if (_activeProfileUid != user.uid || _profileDocSub == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_startInstantProfileHydration(user));
      });
    }

    final pseudo = _profilePseudoController.text.trim();
    final displayName =
        pseudo.isNotEmpty ? pseudo : _deriveImmediatePseudo(user);
    final visibleEmail = _profileEmail.trim().isNotEmpty
        ? _profileEmail.trim()
        : (user.email ?? '');
    final visiblePhotoUrl = customProfilePhotoUrl(_profilePhotoUrl) ?? '';
    final draftCategoryLabels = _draftFavoriteSelections
        .where((entry) => !entry.contains('—'))
        .toList()
      ..sort();
    final draftSubcategoryLabels = _draftFavoriteSelections
        .where((entry) => entry.contains('—'))
        .toList()
      ..sort();

    if (_profileAccountType == 'Entreprise') {
      return _buildEnterpriseScaffold(user, displayName, visiblePhotoUrl);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoOrange),
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
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 150),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête : avatar + nom/localisation/badge
                    _buildDefaultHeader(user, displayName, visiblePhotoUrl),
                    if (_profileSyncInProgress)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Center(
                          child: Text(
                            'Synchronisation…',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (_profileLoadError)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 14,
                                color: Colors.red.shade700,
                              ),
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
                      ),
                    const SizedBox(height: 16),
                    _buildAccountSectionCard(
                      icon: Icons.person_rounded,
                      title: 'Mon profil',
                      description:
                          'Consulte et modifie tes informations personnelles.',
                      isExpanded: _isProfileSectionExpanded,
                      onToggle: () {
                        setState(() {
                          _isProfileSectionExpanded =
                              !_isProfileSectionExpanded;
                        });
                      },
                      alwaysVisibleChild: _profileLoaded
                          ? _buildProfileCompletenessBanner()
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AccountProfileFormSection(
                            firstName: _profileFirstName,
                            lastName: _profileLastName,
                            departmentController: _departmentController,
                            pseudoController: _profilePseudoController,
                            cityController: _profileCityController,
                            phoneController: _profilePhoneController,
                            phoneCountryCode: _profilePhoneCountryCode,
                            isEditing: _isEditingProfile,
                            isSaving: _isSavingProfile,
                            showTitle: false,
                            onStartEditing: () {
                              setState(() {
                                _isEditingProfile = true;
                                _isProfileSectionExpanded = true;
                              });
                            },
                            onPhoneCountryCodeChanged: (code) {
                              if (!mounted ||
                                  _profilePhoneCountryCode == code) {
                                return;
                              }
                              setState(() => _profilePhoneCountryCode = code);
                            },
                            onSave: () async {
                              await _saveProfile(user);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const AccountNotificationsTile(),
                    const SizedBox(height: 8),
                    _buildAccountSectionCard(
                      icon: Icons.tune_rounded,
                      title: 'Mes alertes "Nouvelle annonce"',
                      description:
                          'Organise les alertes qui correspondent à tes préférences.',
                      child: RepaintBoundary(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSubscriptionAlertsBanner(),
                            const SizedBox(height: 8),
                            AccountFavoriteCategoriesSection(
                              categoriesCount: draftCategoryLabels.length,
                              subcategoriesCount: draftSubcategoryLabels.length,
                              selectedCategories: draftCategoryLabels,
                              selectedSubcategories: draftSubcategoryLabels,
                              selectedDepartements:
                                  _selectedFavoriteDepartements.toList()
                                    ..sort(),
                              departementsCount:
                                  _selectedFavoriteDepartements.length,
                              isSaving: _isSavingProfile,
                              showTitle: false,
                              onOpenCategoryPicker: _openCategoryPickerSheet,
                              onOpenSubcategoryPicker:
                                  _openSubcategoryPickerSheet,
                              onOpenDeptPicker: _openDeptPicker,
                              onApply: () => _applyDraftFavorites(user),
                              onRemoveCategory: (category) {
                                setState(() {
                                  _draftFavoriteSelections.remove(category);
                                  _draftFavoriteSelections.removeWhere(
                                    (e) => e.startsWith('\$category — '),
                                  );
                                });
                                unawaited(_applyDraftFavorites(user));
                              },
                              onRemoveSubcategory: (label) {
                                setState(
                                  () => _draftFavoriteSelections.remove(label),
                                );
                                unawaited(_applyDraftFavorites(user));
                              },
                              onRemoveDepartement: (code) {
                                setState(
                                  () => _selectedFavoriteDepartements.remove(
                                    code,
                                  ),
                                );
                                unawaited(_applyDraftFavorites(user));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
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
                    RepaintBoundary(child: const SizedBox.shrink()),
                    const SizedBox(height: 8),
                    SubscriptionSection(userId: user.uid),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AccountSecurityPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.security_rounded),
                        label: const Text(
                          'Sécurité du compte',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildSubscriptionAlertsBanner() {
    const fallbackAsset = 'assets/images/subscription_alerts_banner.png';

    // Aplat neutre affiché tant qu'aucune image n'est prête : aucune image de
    // repli n'apparaît avant la vraie, donc plus de flash visuel.
    const placeholder = ColoredBox(color: Color(0xFFE8F0FE));

    Widget fallback() => Image.asset(
          fallbackAsset,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xFFE8F0FE),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Ne ratez plus aucune offre !',
                  style: TextStyle(
                    color: Color(0xFF1A3A5C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 7,
        child: StreamBuilder<List<AdPlaceholderImage>>(
          stream: _subscriptionAlertsBannerStream,
          builder: (context, snapshot) {
            // Firestore n'a pas encore répondu : on ne sait pas encore s'il
            // existe une image distante, donc on n'affiche rien d'autre qu'un
            // aplat plutôt que la bannière embarquée.
            if (!snapshot.hasData && !snapshot.hasError) return placeholder;

            final activeImages = (snapshot.data ?? const <AdPlaceholderImage>[])
                .where((image) => image.isVisible)
                .toList();
            if (activeImages.isEmpty) return fallback();

            return Image.network(
              activeImages.first.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => fallback(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return placeholder;
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdminSpaceEntry(User user) {
    if (_adminAccessFuture == null || _adminAccessFutureUid != user.uid) {
      _refreshAdminAccessForUser(user.uid, returnOnLocalAdminEvidence: true);
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
          if (_adminLoadingTimedOut) {
            return _buildAdminLoadRetryCard(
              user: user,
              title: 'Vérification admin en cours…',
              message:
                  'La vérification prend plus de temps que prévu. Réessaie ou reconnecte-toi.',
              detail: null,
            );
          }
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
          // Stale-claims: the server denied admin but local token/profile
          // evidence says otherwise — the user was likely granted admin
          // while already signed in. Surface the fallback card with a
          // reconnect hint instead of silently hiding the tile.
          if (accessState.serverErrorCode == 'stale-claims' &&
              accessState.hasLocalAdminEvidence) {
            final fallbackCard = _buildAdminLocalFallbackCard(
              user: user,
              state: accessState,
              detail:
                  "Tes droits admin ont été mis à jour. Déconnecte-toi puis reconnecte-toi pour activer l'espace admin.",
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
          // The server callable failed (network, unauthenticated, function not
          // deployed in the expected region…) but the local token or Firestore
          // profile says the user has admin role. Show a retry card with the
          // diagnosis instead of silently hiding the entry — that way the
          // admin can still trigger a reload or a sign-out / sign-in.
          if (accessState.serverCheckAttempted &&
              !accessState.serverCheckSucceeded &&
              accessState.hasLocalAdminEvidence) {
            final retryCard = _buildAdminLoadRetryCard(
              user: user,
              title: 'Vérification admin temporairement indisponible',
              message:
                  'Tes droits admin sont reconnus localement mais la vérification serveur a échoué. Réessaie ou reconnecte-toi.',
              detail: accessState.serverErrorMessage ??
                  accessState.serverErrorCode ??
                  'Erreur inconnue côté serveur.',
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                retryCard,
                if (_shouldShowAdminDebugCard(user, state: accessState))
                  _buildAdminDebugCard(user, state: accessState),
              ],
            );
          }
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
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kPrestoBlue.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: kPrestoBlue.withValues(alpha: 0.95),
                      ),
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
                          horizontal: 10,
                          vertical: 6,
                        ),
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
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (configLoaded ? kPrestoBlue : Colors.orange)
                              .withValues(alpha: 0.08),
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
                                .withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kPrestoOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Pipeline: ${_adminModeStatusLabel(mode)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: kPrestoOrange.withValues(alpha: 0.92),
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
                            builder: (_) => const AdminSpaceLoader(),
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
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (_shouldShowAdminDebugCard(user, state: accessState)) {
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
              Icon(
                Icons.admin_panel_settings,
                color: kPrestoBlue.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Espace admin',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                        builder: (_) => const AdminSpaceLoader(),
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
                      horizontal: 14,
                      vertical: 12,
                    ),
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

  String get _profileFirstName {
    final pseudo = _profilePseudoController.text.trim();
    final parts =
        pseudo.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.first;
  }

  String get _profileLastName {
    final pseudo = _profilePseudoController.text.trim();
    final parts =
        pseudo.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 1) return '';
    return parts.skip(1).join(' ');
  }

  void _syncProfileDepartmentFromLocation() {
    final code = ProfileDepartmentResolver.resolveDepartmentCode(
      city: _profileCityController.text,
    );
    final label = code == null
        ? ''
        : ProfileDepartmentResolver.departmentDisplayName(code);
    if (_departmentController.text != label) {
      _departmentController.text = label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.idTokenChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Restauration de la session…',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (user == null) {
          SessionState.userId = null;
          CrashlyticsContext.setUserId(null);
          return SignedOutAccountFallback(
            source: 'account-route',
            startInSignup: widget.startInSignup,
          );
        } else {
          return _buildProfile(user);
        }
      },
    );
  }

  // ── Default (Particulier) header ───────────────────────────────────────────

  Widget _buildDefaultHeader(
    User user,
    String displayName,
    String visiblePhotoUrl,
  ) {
    final city = _profileCityController.text.trim();
    final dept = _departmentController.text.trim();
    final locationParts = [dept, city].where((s) => s.isNotEmpty).toList();
    final locationText = locationParts.join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage(
                      'assets/images/default_avatar.webp',
                    ),
                  ),
                  if (visiblePhotoUrl.isNotEmpty)
                    ClipOval(
                      child: Image(
                        image: CachedNetworkImageProvider(visiblePhotoUrl),
                        fit: BoxFit.cover,
                        width: 90,
                        height: 90,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  if (_isUploadingProfilePhoto)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Material(
                color: kPrestoBlue,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isUploadingProfilePhoto
                      ? null
                      : () => unawaited(_pickAndUploadProfilePhoto(user)),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Icon(
                            Icons.add_circle,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              if (locationText.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (user.emailVerified) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 14,
                        color: kPrestoBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Profil vérifié',
                        style: TextStyle(
                          fontSize: 12,
                          color: kPrestoBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Enterprise account layout ──────────────────────────────────────────────

  Widget _buildEnterpriseScaffold(
    User user,
    String displayName,
    String visiblePhotoUrl,
  ) {
    final city = _profileCityController.text.trim();
    final dept = _departmentController.text.trim();
    final locationParts = [dept, city].where((s) => s.isNotEmpty).toList();
    final locationText = locationParts.join(' • ');

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoOrange),
          title: const Text(
            'Mon compte iliprestō',
            style: kPrestoAppBarTitleStyle,
          ),
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
        ),
        backgroundColor: const Color(0xFFF8F8F8),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEnterpriseHeader(
                    user,
                    displayName,
                    visiblePhotoUrl,
                    locationText,
                  ),
                  const SizedBox(height: 10),
                  _buildEspaceConfianceCard(),
                  const SizedBox(height: 8),
                  _buildEnterpriseMenuSection(user),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnterpriseHeader(
    User user,
    String displayName,
    String visiblePhotoUrl,
    String locationText,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage(
                      'assets/images/default_avatar.webp',
                    ),
                  ),
                  if (visiblePhotoUrl.isNotEmpty)
                    ClipOval(
                      child: Image(
                        image: CachedNetworkImageProvider(visiblePhotoUrl),
                        fit: BoxFit.cover,
                        width: 90,
                        height: 90,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kPrestoBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 15),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B3E),
                ),
              ),
              if (locationText.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 14,
                      color: kPrestoBlue,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Profil vérifié',
                      style: TextStyle(
                        fontSize: 12,
                        color: kPrestoBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEspaceConfianceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Row(
                children: const [
                  Icon(Icons.shield_rounded, color: kPrestoOrange, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Espace confiance et activité',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kPrestoOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            _buildOrangeMenuItem(
              icon: Icons.badge_rounded,
              label: 'Ma fiche Pro',
              showProBadge: true,
              onTap: () {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FicheProPage(uid: uid, isOwner: true),
                  ),
                );
              },
            ),
            const Divider(height: 1, thickness: 1, indent: 72),
            _buildOrangeMenuItem(
              icon: Icons.grid_view_rounded,
              label: 'Vérifier mon SIRET',
              showProBadge: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VerifierSiretPage()),
              ),
            ),
            const Divider(height: 1, thickness: 1, indent: 72),
            _buildOrangeMenuItem(
              icon: Icons.star_border_rounded,
              label: 'Mes avis',
              solidBackground: false,
              showProBadge: true,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MesAvisPage())),
            ),
            const Divider(height: 1, thickness: 1, indent: 72),
            _buildOrangeMenuItem(
              icon: Icons.add_circle_outline_rounded,
              label: 'Créer mon activité',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ToolboxPage())),
            ),
            const Divider(height: 1, thickness: 1, indent: 72),
            _buildOrangeMenuItem(
              icon: Icons.route_rounded,
              label: 'Je crée mon entreprise',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MonEntrepriseParcoursPage(),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, indent: 72),
            _buildOrangeMenuItem(
              icon: Icons.folder_rounded,
              label: 'Ma fiche projet',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MesProjetsFichePage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrangeMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool solidBackground = true,
    bool showProBadge = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: solidBackground
                    ? kPrestoOrange
                    : kPrestoOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: solidBackground ? Colors.white : kPrestoOrange,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  if (showProBadge) ...[
                    const SizedBox(width: 8),
                    const _IliProBadge(),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterpriseMenuSection(User user) {
    return Column(
      children: [
        AccountMenuItem(
          icon: Icons.campaign_rounded,
          label: 'Mes annonces',
          onTap: () => showPrestoSnackBar(
            context,
            'Annonces — Bientôt disponible depuis ici',
          ),
        ),
        const Divider(height: 1, thickness: 1, indent: 72),
        AccountMenuItem(
          icon: Icons.security_rounded,
          label: 'Sécurité du compte',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountSecurityPage()),
            );
          },
        ),
        const Divider(height: 1, thickness: 1, indent: 72),
        AccountMenuItem(
          icon: Icons.language_rounded,
          label: 'Langue de l\'application',
          onTap: () => showLanguagePickerSheet(context),
        ),
        const Divider(height: 1, thickness: 1, indent: 72),
        AccountMenuItem(
          icon: Icons.gavel_rounded,
          label: 'Mentions légales',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LegalInfoPage())),
        ),
        const Divider(height: 1, thickness: 1, indent: 72),
        AccountMenuItem(
          icon: Icons.logout_rounded,
          label: 'Déconnexion',
          onTap: _isSigningOut ? () {} : _signOut,
          trailing: _isSigningOut
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kPrestoBlue,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _DeptPickerDialog extends StatefulWidget {
  final Set<String> selected;
  const _DeptPickerDialog({required this.selected});

  @override
  State<_DeptPickerDialog> createState() => _DeptPickerDialogState();
}

class _DeptPickerDialogState extends State<_DeptPickerDialog> {
  late Set<String> _current;
  String _query = '';

  static const _dromCodes = ['971', '972', '973', '974', '975', '976'];

  @override
  void initState() {
    super.initState();
    _current = Set<String>.from(widget.selected);
  }

  List<MapEntry<String, String>> get _filtered {
    final q = _query.trim().toLowerCase();
    final entries = kDepartments.entries.toList();
    final drom = entries.where((e) => _dromCodes.contains(e.key)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final metro = entries.where((e) => !_dromCodes.contains(e.key)).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final all = [...drom, ...metro];
    if (q.isEmpty) return all;
    return all
        .where((e) => e.value.toLowerCase().contains(q) || e.key.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return AlertDialog(
      title: const Text('Départements d\'alerte'),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un département...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final e = filtered[i];
                  final isDrom = _dromCodes.contains(e.key);
                  return CheckboxListTile(
                    dense: true,
                    title: Text(
                      '${e.value} (${e.key})',
                      style: TextStyle(
                        fontWeight:
                            isDrom ? FontWeight.w700 : FontWeight.normal,
                        color: isDrom ? kPrestoBlue : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    value: _current.contains(e.key),
                    onChanged: (v) => setState(
                      () => v == true
                          ? _current.add(e.key)
                          : _current.remove(e.key),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF009688),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Annuler'),
        ),
        if (_current.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _current.clear()),
            child: const Text('Effacer', style: TextStyle(color: Colors.red)),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF009688),
            foregroundColor: Colors.white,
          ),
          onPressed: () =>
              Navigator.of(context).pop(Set<String>.from(_current)),
          child: Text(
            _current.isEmpty ? 'Tous' : 'Valider (${_current.length})',
          ),
        ),
      ],
    );
  }
}

class _IliProBadge extends StatelessWidget {
  const _IliProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6600), Color(0xFFFFB300)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 11, color: Colors.white),
          SizedBox(width: 3),
          Text(
            'ili-pro',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.3,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
