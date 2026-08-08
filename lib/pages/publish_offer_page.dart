import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../app/app_globals.dart';
import '../app/system_ui_style.dart' show prestoOverlayStyleFor;
import 'home_page.dart' show HomePage;
import 'account_page.dart';
import '../app/presto_overlay_theme.dart';
import '../app_core.dart';
import '../constants.dart';
import '../config/app_check_state.dart';
import '../config/env/openai_config.dart';
import '../features/ai_draft/ai_draft_service.dart';
import '../features/micro_ia/micro_ia_service.dart';
import '../features/publish_ai/profile_readiness.dart';
import '../features/micro_ia/web_audio_recorder_stub.dart'
    if (dart.library.js_interop) '../features/micro_ia/web_audio_recorder.dart';
import '../models/admin_access_state.dart';
import '../services/admin_access_resolver.dart';
import '../services/admin_web_debug_store.dart';
import '../services/ai/listing_audio_ai_service.dart';
import '../services/ai/trade_classifier_service.dart';
import '../services/city_search.dart';
import '../services/firebase_functions_region.dart';
import '../services/french_city_postal_validator.dart';
import '../services/marketplace_publish_service.dart';
import '../services/geo_api_gouv_service.dart';
import '../services/location_text_normalizer.dart';
import '../services/marketplace_remote_config_service.dart';
import '../services/offer_indexing.dart';
import '../services/admin_audio_runtime_store.dart';
import '../services/user_profile_bootstrap_service.dart';
import '../utils/crashlytics_context.dart';
import '../utils/friendly_snackbar.dart';
import '../utils/runtime_action_logger.dart';
import '../utils/recording_path_web.dart'
    if (dart.library.io) '../utils/recording_path_io.dart';
import '../widgets/ai_publish_control_with_credits.dart';
import 'publish_offer_widgets.dart';
import '../features/offers/presentation/widgets/publish_offer_photos_section.dart';
import '../features/offers/presentation/widgets/publish_offer_category_fields.dart';
import '../features/offers/presentation/widgets/publish_offer_contact_fields.dart';
import '../features/offers/presentation/widgets/publish_offer_mission_fields.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/orbiting_ai_visual.dart';

final AdminAudioRuntimeStore _adminAudioRuntimeStore =
    AdminAudioRuntimeStore.instance;

enum PublishOfferAiFlowStep {
  chooseMethod,
  voiceSelected,
  voiceAnalyzing,
  textSelected,
  textAnalyzing,
  completed,
}

class PublishOfferPage extends StatefulWidget {
  final Function(double)? onScroll;

  const PublishOfferPage({super.key, this.onScroll});

  @override
  State<PublishOfferPage> createState() => _PublishOfferPageState();
}

class _PublishOfferPageState extends State<PublishOfferPage> {
  MarketplacePublishService? _marketplacePublishService;
  static const int _publishPhotoHardLimit = 2;
  static const int _defaultMaxListingPhotos = _publishPhotoHardLimit;
  static const int _minimumMaxListingPhotos = 1;

  final MarketplaceRemoteConfigService _marketplaceRemoteConfigService =
      MarketplaceRemoteConfigService();
  int _maxListingPhotos = _defaultMaxListingPhotos;

  String formatMicroIaRuntimeError(Object error) {
    if (error is MicroIaClientAuthException) {
      return error.message;
    }

    if (error is FirebaseFunctionsException) {
      final code = error.code.trim();
      final message = (error.message ?? '').trim();
      if (code == 'unauthenticated') {
        return 'Connecte-toi pour utiliser la dictée.';
      }
      if (code == 'permission-denied') {
        return 'Cette dictée ne correspond plus à ta session. Recharge la page puis réessaie.';
      }
      if (code == 'not-found') {
        return 'Service vocal temporairement indisponible. Réessaie dans quelques instants.';
      }
      if (code == 'unavailable' || code == 'deadline-exceeded') {
        return 'Serveur vocal occupé. Réessaie dans quelques secondes.';
      }
      if (message.isNotEmpty) {
        return translatePublishIssue(message);
      }
      return translatePublishIssue(code);
    }

    if (error is FirebaseException) {
      if (error.code == 'network-error' ||
          error.code == 'retry-limit-exceeded' ||
          error.code == 'unknown') {
        return "Erreur réseau lors de l'envoi de l'audio. Vérifie ta connexion puis réessaie.";
      }
      if (error.code == 'unauthorized' || error.code == 'permission-denied') {
        return 'Accès au stockage refusé. Recharge la page puis réessaie.';
      }
      return 'Erreur de stockage (${error.code}). Réessaie.';
    }

    final message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '')
        .trim();
    final normalized = message.toLowerCase();
    if (normalized.contains('bad state') ||
        normalized.contains('recorder not started')) {
      return 'Le micro a été interrompu. Réessaie.';
    }
    if (normalized.contains('unable to decode audio data') ||
        normalized.contains('unknown content type') ||
        normalized.contains('not supported')) {
      return "Le navigateur n'a pas pu lire l'audio. Réessaie ou recharge la page.";
    }
    if (normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('fetch')) {
      return 'Problème de connexion réseau. Vérifie ta connexion puis réessaie.';
    }
    if (normalized.contains('403') ||
        normalized.contains('forbidden') ||
        normalized.contains('app check') ||
        normalized.contains('appcheck')) {
      return 'Vérification de sécurité échouée. Recharge la page puis réessaie.';
    }
    if (normalized.contains('aucun texte reconnu') ||
        normalized.contains('audio invalide') ||
        normalized.contains('transcription vide') ||
        normalized.contains('transcript vide')) {
      return 'Veuillez ré-enregistrer votre audio.';
    }
    return message;
  }

  Future<bool> _ensureAppCheckReady({
    required String flow,
    bool showBlockingMessage = true,
  }) async {
    if (!_useCloudStt) return true;

    if (appCheckActivationSucceeded) {
      _appendPublishAiTrace(
        'appcheck',
        'App Check OK pour $flow',
        level: PublishAiTraceLevel.success,
      );
      return true;
    }

    try {
      if (!appCheckActivationAttempted) {
        throw StateError(
          'App Check non initialise par le bootstrap pour $flow',
        );
      }
      final appCheckToken = await FirebaseAppCheck.instance
          .getToken(true)
          .timeout(const Duration(seconds: 8));
      if ((appCheckToken ?? '').trim().isEmpty) {
        throw StateError('Jeton App Check vide apres reactive pour $flow');
      }
      appCheckActivationAttempted = true;
      appCheckActivationSucceeded = true;
      appCheckActivationError = null;
      appCheckActivationStackTrace = null;
      _appendPublishAiTrace(
        'appcheck',
        'App Check token OK pour $flow',
        level: PublishAiTraceLevel.success,
      );
      return true;
    } catch (e, st) {
      appCheckActivationAttempted = true;
      appCheckActivationSucceeded = false;
      appCheckActivationError = e;
      appCheckActivationStackTrace = st;
    }

    final activationError = appCheckActivationError;
    final activationStackTrace = appCheckActivationStackTrace;
    final exception = Exception(
      'App Check activation unavailable: ${activationError ?? 'unknown error'}',
    );

    try {
      await CrashlyticsContext.recordError(
        exception,
        activationStackTrace ?? StackTrace.current,
        reason: 'App Check activation unavailable before micro IA flow',
        fatal: false,
        keys: {
          'component': 'Main',
          'flow': flow,
          'step': 'appCheck',
          'activationAttempted': appCheckActivationAttempted.toString(),
          'activationSucceeded': appCheckActivationSucceeded.toString(),
        },
      );

      debugPrint('[AppCheck] blocking $flow: $activationError');
    } catch (_) {}

    _appendPublishAiTrace(
      'appcheck',
      'Blocage sur $flow: ${activationError ?? 'activation indisponible'}',
      level: PublishAiTraceLevel.error,
    );

    if (mounted && showBlockingMessage) {
      showErrorSnackBar(
        context,
        'App Check indisponible apres nouvelle tentative. Le bouton IA reste bloque tant que la verification de securite n\'est pas active. Recharge l\'application puis reessaie.',
      );
    }
    return false;
  }

  /// Uploade l'audio, appelle microIaProcessAudio avec generateDraft:true pour
  /// obtenir transcription + brouillon en un seul round-trip, et retourne les
  /// deux dans une Map {text, draft?}.
  Future<Map<String, dynamic>> _transcribePublishAudio({
    required String ownerUid,
    required Uint8List audioBytes,
    required String contentType,
    required String extension,
  }) async {
    _appendPublishAiTrace(
      'upload_audio',
      'Préparation envoi ${audioBytes.length} bytes, $contentType, .$extension',
    );
    _logMicroIaDebug(
      'UPLOAD',
      'chunk=final bytes=${audioBytes.length} contentType=$contentType extension=$extension',
    );

    // ⚡ Chemin rapide : l'audio part en base64 directement dans le callable,
    // sans passer par Firebase Storage (upload client + re-download serveur
    // évités, ~1-2,5 s gagnées). Fallback Storage pour les gros audios.
    const inlineAudioLimitBytes = 2 * 1024 * 1024;
    final useInlineAudio = audioBytes.length <= inlineAudioLimitBytes;

    String? storagePath;
    if (useInlineAudio) {
      _appendPublishAiTrace(
        'upload_audio',
        'Envoi direct dans le callable (${audioBytes.length} bytes, sans upload Storage)',
        level: PublishAiTraceLevel.success,
      );
    } else {
      storagePath = await _listingAudioAiService.uploadAudioBytes(
        ownerUid: ownerUid,
        audioBytes: audioBytes,
        contentType: contentType,
        extension: extension,
      );
      _appendPublishAiTrace(
        'upload_audio',
        'Audio uploadé vers $storagePath',
        level: PublishAiTraceLevel.success,
      );
    }

    _appendPublishAiTrace(
      'microia_callable',
      'Appel microIaProcessAudio (mode combiné STT+draft) en cours',
    );

    // Mode combiné : transcription + brouillon en un seul appel (~1-2 s gagnés)
    final currentCity = _locationController.text.trim();
    final out = await MicroIaService.processAudio(
      storagePath: storagePath,
      audioBase64: useInlineAudio ? base64Encode(audioBytes) : null,
      audioContentType: useInlineAudio ? contentType : null,
      languageCode: OpenAiConfig.defaultLanguageCode,
      generateDraft: true,
      draftCity: currentCity.isNotEmpty ? currentCity : null,
      draftCategory: _category,
      debugLabel: 'publish_final_audio',
    ).timeout(const Duration(seconds: 90));

    final transcript = (out['text'] ?? '').toString().trim();
    if (transcript.isEmpty) {
      _appendPublishAiTrace(
        'microia_callable',
        'Réponse reçue mais transcription vide',
        level: PublishAiTraceLevel.error,
      );
      throw Exception('Aucun texte reconnu');
    }

    final modeUsed = (out['modeUsed'] ?? '').toString().trim();
    if (modeUsed.isNotEmpty) {
      _adminAudioRuntimeStore.confirmLatestBackendResult(
        backendModeUsed: modeUsed,
        detail:
            'Réponse backend confirmée via $modeUsed (${transcript.length} caractères)',
        transcriptLength: transcript.length,
      );
    }

    final hasCombinedDraft = out['draft'] is Map;
    _appendPublishAiTrace(
      'microia_callable',
      modeUsed.isEmpty
          ? 'Transcription reçue (${transcript.length} car.) — draft=${hasCombinedDraft ? 'ok' : 'absent'}'
          : 'Transcription reçue via $modeUsed (${transcript.length} car.) — draft=${hasCombinedDraft ? 'ok' : 'absent'}',
      level: PublishAiTraceLevel.success,
    );

    return {
      'text': transcript,
      'draft': hasCombinedDraft
          ? Map<String, dynamic>.from(out['draft'] as Map)
          : null,
    };
  }

  /// Applique la transcription au formulaire.
  /// Si [combinedDraft] est fourni (mode combiné), l'utilise directement sans
  /// appel réseau supplémentaire. Sinon, appelle generateOfferDraftV2 en fallback.
  Future<void> _applyPublishDraftFromTranscript(
    String transcript, {
    Map<String, dynamic>? combinedDraft,
  }) async {
    _latestRecognizedTranscript = transcript;
    _appendPublishAiTrace(
      'draft_local',
      'Pré-remplissage local depuis la transcription (${transcript.length} caractères)',
    );
    _applyFastDraftFromTranscript(transcript);

    final Map<String, dynamic> draft;
    if (combinedDraft != null) {
      // Draft déjà généré par microIaProcessAudio — aucun appel réseau supplémentaire
      _appendPublishAiTrace(
        'draft_remote',
        'Brouillon combiné disponible — utilisation directe (0 appel supplémentaire)',
        level: PublishAiTraceLevel.success,
      );
      draft = {...combinedDraft, 'success': true};
    } else {
      // Fallback : appel séparé avec format riche (tous les champs)
      _appendPublishAiTrace(
        'draft_remote',
        'Appel generateOfferDraftV2 depuis la transcription (fallback)',
      );
      draft = await _aiService.generateOfferDraftV2(text: transcript);
      _appendPublishAiTrace(
        'draft_remote',
        'Réponse generateOfferDraftV2 reçue',
        level: draft['success'] == true
            ? PublishAiTraceLevel.success
            : PublishAiTraceLevel.warning,
      );
    }

    if (!mounted) return;

    if (draft['success'] == true) {
      _applyDraftToForm(draft);
      _appendPublishAiTrace(
        'draft_remote',
        'Champs du formulaire remplis par le draft IA',
        level: PublishAiTraceLevel.success,
      );
      showSuccessSnackBar(context, 'Transcription réussie et champs remplis');
      return;
    }

    final code = (draft['code'] ?? '').toString();
    throw Exception(
      code == 'deadline-exceeded'
          ? 'Connexion lente, réessaie.'
          : (draft['error'] ?? 'Erreur IA inconnue').toString(),
    );
  }

  /// Bouton micro: utiliser le flux audio classique, qui traite l'audio au stop
  /// et remplit les champs via le pipeline STT + draft.

  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final LayerLink _publishAiMicAnchorLink = LayerLink();

  bool _isUrgent = false;
  bool _hidePhone = false;

  // ✅ Analytics
  // late final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// ✅ Enregistre la publication d'une offre
  Future<void> _logOfferPublished({
    required String offerId,
    required String title,
    required String category,
    required String? budget,
    required String budgetType,
  }) async {
    try {
      /*
      await _analytics.logEvent(
        name: 'ecommerce_purchase',
        parameters: {
          'value': (budget != null && budget.isNotEmpty)
              ? double.tryParse(budget) ?? 0.0
              : 0.0,
          'currency': 'EUR',
          'transaction_id': offerId,
          'items': [
            {
              'item_id': offerId,
              'item_name': title,
              'item_category': category,
            },
          ],
        },
      );

      // ✅ Event personnalisé supplémentaire
      await _analytics.logEvent(
        name: 'offer_published',
        parameters: {
          'offer_id': offerId,
          'title': title,
          'category': category,
          'budget_type': budgetType,
          'has_photos': _selectedPhotos.isNotEmpty,
          'photo_count': _selectedPhotos.length,
          'is_urgent': _isUrgent,
        },
      );
      */
    } catch (e) {
      debugPrint('[Analytics] logOfferPublished error: $e');
    }
  }

  // Champs texte
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final GeoApiGouvService _geoApiGouvService = GeoApiGouvService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  late final FocusNode _descriptionFocusNode = FocusNode();

  // Indicatif téléphonique sélectionné
  String _selectedPhoneCountryCode = '+33';

  // Catégories / sous-catégories
  String? _category;
  String? _selectedSubCategory;

  List<String> get _categories =>
      kCategorySubcategories.keys.toList(); // Map<String, List<String>>

  // Budget: type (fixe / à négocier)
  final List<String> _budgetTypes = const ['Fixe', 'À négocier'];
  String _budgetType = 'Fixe';

  // Délai pour effectuer la mission
  final List<String> _missionDelayOptions = const [
    'Urgent',
    'Dans la journée',
    'Demain',
    'Sous 48h',
    'Cette semaine',
    'À convenir',
  ];
  String? _missionDelay;

  // Photos marketplace
  final List<XFile> _selectedPhotos = [];
  final List<Uint8List?> _selectedPhotoBytes = [];

  FirebaseFunctions get _functions => prestoFirebaseFunctions;

  // Autocomplétion villes
  List<CityRecord> _citySuggestions = [];

  // Région / département (optionnel à exploiter dans le futur)

  bool _isSubmitting = false;
  bool _isAnalyzing = false;
  bool _isListening = false;

  bool _attemptedSubmit = false; // affiche erreurs après tentative
  bool _publishLocked = false; // lock après tentative invalide
  bool _canPublish = false;
  bool _showDarkOverlay = false;
  String _latestRecognizedTranscript = '';
  PublishOfferAiFlowStep _publishAiFlowStep =
      PublishOfferAiFlowStep.chooseMethod;
  bool _descriptionTapToEditPrimed = false;
  bool _isApplyingProgrammaticPublishUpdate = false;
  bool _titleEditedByUser = false;
  bool _descriptionEditedByUser = false;
  bool _locationEditedByUser = false;
  bool _postalCodeEditedByUser = false;
  bool _locationPostalPrefilledByAi = false;
  bool _isClearingAiPrefilledLocationPostal = false;
  bool _categoryEditedByUser = false;
  bool _delayEditedByUser = false;
  bool _budgetEditedByUser = false;
  final List<PublishAiTraceEntry> _publishAiTraceEntries =
      <PublishAiTraceEntry>[];
  final ValueNotifier<int> _publishAiTraceVersion = ValueNotifier<int>(0);
  bool _publishAiTraceDisposed = false;
  int _publishAiTraceAttempt = 0;
  String? _shakingPublishFieldId;
  int _publishShakeTick = 0;

  FirebaseAuth? get _authOrNull {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestoreOrNull {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final GlobalKey _titleFieldKey = GlobalKey();
  final GlobalKey _categoryFieldKey = GlobalKey();
  final GlobalKey _publishAiFlowHintKey = GlobalKey();
  final GlobalKey _descriptionFieldKey = GlobalKey();
  final GlobalKey _cityFieldKey = GlobalKey();
  final GlobalKey _phoneFieldKey = GlobalKey();
  final GlobalKey _delayFieldKey = GlobalKey();
  final GlobalKey _budgetFieldKey = GlobalKey();

  // Service IA structuré pour le formulaire publier
  final AiDraftService _aiService = AiDraftService();
  final ListingAudioAiService _listingAudioAiService = ListingAudioAiService();
  final TradeClassifierService _tradeClassifier = TradeClassifierService();
  bool _isClassifyingPhoto = false;
  final AdminAccessResolver _publishAdminAccessResolver = AdminAccessResolver();
  final ProfileReadinessChecker _publishAiProfileReadiness =
      ProfileReadinessChecker();
  final AudioRecorder _recorder = AudioRecorder();
  final WebAudioRecorder _webRec = WebAudioRecorder();
  String? _recordingPath;
  // Toujours actif (améliore la qualité via Google STT côté serveur)
  final bool _useCloudStt = true;
  int _adminAudioRuntimeAccessState = 0;
  String _adminAudioRuntimeMode = 'HYBRID';
  String _adminAudioRuntimeLabel = 'Mode serveur';

  void _runWithoutMarkingUserEdits(VoidCallback action) {
    final previous = _isApplyingProgrammaticPublishUpdate;
    _isApplyingProgrammaticPublishUpdate = true;
    try {
      action();
    } finally {
      _isApplyingProgrammaticPublishUpdate = previous;
    }
  }

  void _notifyPublishAiTraceChanged() {
    if (_publishAiTraceDisposed) return;
    _publishAiTraceVersion.value++;
  }

  void _resetPublishAiTrace(String flowLabel) {
    _publishAiTraceAttempt += 1;
    _publishAiTraceEntries
      ..clear()
      ..add(
        PublishAiTraceEntry(
          timestamp: DateTime.now(),
          level: PublishAiTraceLevel.info,
          stage: 'start',
          detail: 'Essai #$_publishAiTraceAttempt lance via $flowLabel',
        ),
      );
    _notifyPublishAiTraceChanged();
  }

  void _appendPublishAiTrace(
    String stage,
    String detail, {
    PublishAiTraceLevel level = PublishAiTraceLevel.info,
  }) {
    if (_publishAiTraceEntries.length >= 120) {
      _publishAiTraceEntries.removeAt(0);
    }
    _publishAiTraceEntries.add(
      PublishAiTraceEntry(
        timestamp: DateTime.now(),
        level: level,
        stage: stage,
        detail: detail,
      ),
    );
    AdminWebDebugStore.instance.recordEvent(
      area: 'publish-ai',
      message: stage,
      level: switch (level) {
        PublishAiTraceLevel.error => 'error',
        PublishAiTraceLevel.warning => 'warn',
        PublishAiTraceLevel.success => 'success',
        PublishAiTraceLevel.info => 'info',
      },
      detail: detail,
    );
    _notifyPublishAiTraceChanged();
  }

  void _clearPublishAiTrace() {
    _publishAiTraceEntries.clear();
    _notifyPublishAiTraceChanged();
  }

  String publishAiDebugValue(Object? value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'yes' : 'no';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  void _appendAdminAccessDiagnosticTrace(
    String stage,
    Map<String, dynamic> payload, {
    PublishAiTraceLevel level = PublishAiTraceLevel.info,
  }) {
    final debug = payload['debug'] is Map
        ? Map<String, dynamic>.from(payload['debug'] as Map)
        : const <String, dynamic>{};
    final parts = <String>[
      'uid=${publishAiDebugValue(payload['uid'])}',
      'isAdmin=${publishAiDebugValue(payload['isAdmin'])}',
      'source=${publishAiDebugValue(payload['source'])}',
    ];

    if (debug.isNotEmpty) {
      parts.addAll(<String>[
        'tokenAdmin=${publishAiDebugValue(debug['tokenHasAdmin'])}',
        'userDoc=${publishAiDebugValue(debug['userDocExists'])}',
        'userAdmin=${publishAiDebugValue(debug['userHasAdmin'])}',
        'adminDoc=${publishAiDebugValue(debug['adminDocExists'])}',
        'adminEnabled=${publishAiDebugValue(debug['adminDocEnabled'])}',
      ]);
    }

    _appendPublishAiTrace(stage, parts.join(' | '), level: level);
  }

  void _appendAdminAccessStateTrace(
    String stage,
    AdminAccessState state, {
    PublishAiTraceLevel level = PublishAiTraceLevel.info,
  }) {
    final parts = <String>[
      'uid=${publishAiDebugValue(state.uid)}',
      'effectiveAdmin=${publishAiDebugValue(state.effectiveIsAdmin)}',
      'source=${publishAiDebugValue(state.sourceOfTruth)}',
      'tokenAdmin=${publishAiDebugValue(state.tokenHasAdmin)}',
      'profileAdmin=${publishAiDebugValue(state.profileHasAdmin)}',
      'serverOk=${publishAiDebugValue(state.serverCheckSucceeded)}',
      'serverAdmin=${publishAiDebugValue(state.serverIsAdmin)}',
    ];

    if ((state.serverErrorCode ?? '').trim().isNotEmpty) {
      parts.add('serverError=${publishAiDebugValue(state.serverErrorCode)}');
    }

    _appendPublishAiTrace(stage, parts.join(' | '), level: level);
  }

  String _publishAdminRuntimeDetail(AdminAccessState state) {
    if (state.serverCheckSucceeded && state.serverIsAdmin == true) {
      return 'Accès admin confirmé';
    }
    if (state.effectiveIsAdmin) {
      final source = state.sourceOfTruth.trim().isEmpty
          ? 'token/profil'
          : state.sourceOfTruth;
      return 'Accès admin confirmé via $source';
    }
    if ((state.serverErrorMessage ?? '').trim().isNotEmpty) {
      return state.serverErrorMessage!.trim();
    }
    if ((state.serverErrorCode ?? '').trim().isNotEmpty) {
      return 'Vérification admin indisponible (${state.serverErrorCode})';
    }
    return 'Accès admin non confirmé';
  }

  String _currentPublishAiRuntimeState() {
    if (_isListening) return 'Ecoute micro';
    if (_isAnalyzing) return 'Analyse en cours';
    return 'En attente';
  }

  void _logMicroIaDebug(String stage, String message) {
    AdminWebDebugStore.instance.recordEvent(
      area: 'publish-ai',
      message: stage,
      detail: message,
    );
    debugPrint('[MICIA][$stage] $message');
  }

  Future<MicroIaSecureContext?> _requirePublishAiSecureContext({
    required String stage,
    bool forceRefreshToken = false,
    bool showUserMessage = true,
  }) async {
    try {
      final secureContext = await MicroIaService.prepareSecureCallableContext(
        forceRefreshToken: forceRefreshToken,
      );
      _appendPublishAiTrace(
        'auth',
        'Session OK uid=${secureContext.uid} token=ok appcheck=${secureContext.hasAppCheckToken ? 'ok' : 'missing'}',
        level: PublishAiTraceLevel.success,
      );
      _logMicroIaDebug(
        'AUTH',
        'uid=${secureContext.uid} email=${secureContext.email ?? ''} stage=$stage',
      );
      _logMicroIaDebug('TOKEN', 'fetched=yes stage=$stage');
      _logMicroIaDebug(
        'APPCHECK',
        'token=${secureContext.hasAppCheckToken ? 'yes' : 'no'} stage=$stage',
      );
      return secureContext;
    } on MicroIaClientAuthException catch (error) {
      _appendPublishAiTrace(
        'auth',
        error.message,
        level: PublishAiTraceLevel.error,
      );
      _logMicroIaDebug('AUTH', 'user=null code=${error.code} stage=$stage');
      _logMicroIaDebug('TOKEN', 'fetched=no stage=$stage');
      if (showUserMessage && mounted) {
        showErrorSnackBar(context, error.message);
      }
      return null;
    } catch (error) {
      final message = formatMicroIaRuntimeError(error);
      _appendPublishAiTrace('auth', message, level: PublishAiTraceLevel.error);
      _logMicroIaDebug('AUTH', 'unexpected_error stage=$stage err=$message');
      if (showUserMessage && mounted) {
        showErrorSnackBar(context, message);
      }
      return null;
    }
  }

  String adminAudioModeLabel(String mode) {
    switch (mode.toUpperCase()) {
      case 'GOOGLE_ONLY':
        return 'Google STT';
      case 'WHISPER_ONLY':
        return 'Whisper';
      case 'HYBRID':
      default:
        return 'Hybride';
    }
  }

  String _classicAdminAudioRuntimeDetail() {
    switch (_adminAudioRuntimeMode.toUpperCase()) {
      case 'GOOGLE_ONLY':
        return 'Micro classique -> transcription Google STT uniquement';
      case 'WHISPER_ONLY':
        return 'Micro classique -> transcription Whisper uniquement';
      case 'HYBRID':
      default:
        return 'Micro classique -> Google STT puis nettoyage IA, avec fallback Whisper/Google';
    }
  }

  Future<void> _refreshAdminAudioRuntimeAccess() async {
    // Test-safe + UX-safe :
    // ne pas attendre authStateChanges().timeout(5s) au simple montage de la page.
    // Le check admin audio n'est utile que si un utilisateur est déjà connu.
    final currentUser = _authOrNull?.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _adminAudioRuntimeAccessState = 0;
      });
      return;
    }

    final user = await _ensureProtectedSessionReady(forceRefreshToken: true);
    if (user == null) {
      _appendPublishAiTrace(
        'admin_check',
        'Aucun utilisateur FirebaseAuth disponible pour la verification admin',
        level: PublishAiTraceLevel.warning,
      );
      if (!mounted) return;
      setState(() {
        _adminAudioRuntimeAccessState = 0;
      });
      return;
    }

    try {
      final accessState = await _publishAdminAccessResolver.resolveAdminAccess(
        forceRefresh: true,
      );
      _appendAdminAccessStateTrace(
        'admin_check',
        accessState,
        level: accessState.effectiveIsAdmin
            ? PublishAiTraceLevel.success
            : PublishAiTraceLevel.warning,
      );

      if (!accessState.effectiveIsAdmin) {
        if (!mounted) return;
        setState(() {
          _adminAudioRuntimeAccessState = -1;
          if (_adminAudioRuntimeLabel == 'Mode serveur') {
          }
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _adminAudioRuntimeAccessState = 1;
        if (_adminAudioRuntimeLabel == 'Mode serveur') {
        }
      });
      unawaited(_adminAudioRuntimeStore.enableCloudSync());

      try {
        await MicroIaService.prepareSecureCallableContext(
          forceRefreshToken: true,
          forceRefreshAppCheckToken: true,
        );
        final configCallable = _functions.httpsCallable(
          'adminGetMicroIaConfig',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        );
        HttpsCallableResult<dynamic> configRes;
        try {
          configRes = await configCallable.call<dynamic>({});
        } on FirebaseFunctionsException catch (e) {
          if (e.code != 'unauthenticated' && e.code != 'permission-denied') {
            rethrow;
          }
          _appendPublishAiTrace(
            'admin_config',
            'Re-tentative apres refresh token+appcheck (code=${e.code})',
            level: PublishAiTraceLevel.warning,
          );
          await MicroIaService.prepareSecureCallableContext(
            forceRefreshToken: true,
            forceRefreshAppCheckToken: true,
          );
          configRes = await configCallable.call<dynamic>({});
        }
        final data = Map<String, dynamic>.from(configRes.data as Map);
        final mode = (data['mode'] ?? 'HYBRID').toString().toUpperCase();
        _appendPublishAiTrace(
          'admin_config',
          'mode=${publishAiDebugValue(mode)} source=${publishAiDebugValue(data['source'])}',
          level: PublishAiTraceLevel.success,
        );

        if (!mounted) return;
        setState(() {
          _adminAudioRuntimeMode = mode;
          if (_adminAudioRuntimeLabel == 'Mode serveur') {
          }
        });
        unawaited(_adminAudioRuntimeStore.enableCloudSync());
        _adminAudioRuntimeStore.updateConfiguredMode(mode);
      } on FirebaseFunctionsException catch (e) {
        _appendPublishAiTrace(
          'admin_config',
          'Erreur config code=${e.code} message=${publishAiDebugValue(e.message)}',
          level: PublishAiTraceLevel.warning,
        );
        if (!mounted) return;
        setState(() {
          _adminAudioRuntimeAccessState = 1;
          if (_adminAudioRuntimeLabel == 'Mode serveur') {
          }
        });
      } catch (error) {
        _appendPublishAiTrace(
          'admin_config',
          'Erreur config inattendue: ${publishAiDebugValue(error)}',
          level: PublishAiTraceLevel.warning,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      _appendPublishAiTrace(
        'admin_check',
        'Erreur callable code=${e.code} message=${publishAiDebugValue(e.message)} uid=${user.uid}',
        level: PublishAiTraceLevel.error,
      );
      if ((e.code == 'permission-denied' || e.code == 'unauthenticated') &&
          user.uid.isNotEmpty) {
        await _ensureProtectedSessionReady(forceRefreshToken: true);
        if (!mounted) return;
        try {
          final retryCallable = _functions.httpsCallable(
            'getMyAdminAccessStatus',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          );
          final retryRes = await retryCallable.call<dynamic>({});
          final retryData = Map<String, dynamic>.from(retryRes.data as Map);
          _appendAdminAccessDiagnosticTrace(
            'admin_retry',
            retryData,
            level: retryData['isAdmin'] == true
                ? PublishAiTraceLevel.success
                : PublishAiTraceLevel.warning,
          );
          if (retryData['isAdmin'] != true) {
            throw FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'Accès admin non confirmé après nouvelle tentative.',
            );
          }
          if (!mounted) return;
          setState(() {
            _adminAudioRuntimeAccessState = 1;
            if (_adminAudioRuntimeLabel == 'Mode serveur') {
            }
          });
          return;
        } on FirebaseFunctionsException {
          // Laisse la gestion standard ci-dessous.
        } catch (_) {
          // Laisse la gestion standard ci-dessous.
        }
      }
      if (!mounted) return;
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        setState(() {
          _adminAudioRuntimeAccessState = -1;
          if (_adminAudioRuntimeLabel == 'Mode serveur') {
          }
        });
      }
    } catch (_) {
      _appendPublishAiTrace(
        'admin_check',
        'Erreur inattendue pendant la verification admin',
        level: PublishAiTraceLevel.error,
      );
      if (!mounted) return;
      setState(() {
        _adminAudioRuntimeAccessState = -1;
        if (_adminAudioRuntimeLabel == 'Mode serveur') {
        }
      });
    }
  }

  void _rememberAdminAudioRuntime({
    required String flowKey,
    required String label,
    required String detail,
    String status = 'pending',
    String? backendModeUsed,
  }) {
    _adminAudioRuntimeLabel = label;
    _adminAudioRuntimeStore.recordRuntime(
      flowKey: flowKey,
      label: label,
      detail: detail,
      status: status,
      backendModeUsed: backendModeUsed,
    );
  }

  Future<void> _showPublishAiTraceDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<int>(
          valueListenable: _publishAiTraceVersion,
          builder: (context, _, __) {
            return PublishAiTraceDiagnosticDialog(
              entries: List<PublishAiTraceEntry>.unmodifiable(
                _publishAiTraceEntries,
              ),
              runtimeState: _currentPublishAiRuntimeState(),
              latestTranscript: _latestRecognizedTranscript,
              onClear: _clearPublishAiTrace,
            );
          },
        );
      },
    );
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    _runWithoutMarkingUserEdits(() {
      controller.value = controller.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    });
  }

  void _handlePublishTitleChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _titleEditedByUser = true;
  }

  void _handlePublishDescriptionChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _descriptionEditedByUser = true;
  }

  void _handlePublishLocationChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _locationEditedByUser = true;
  }

  void _handlePublishPostalCodeChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _postalCodeEditedByUser = true;
  }

  void _handlePublishBudgetChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _budgetEditedByUser = true;
  }

  AiPublishState get _aiPublishState {
    if (_isListening) return AiPublishState.recording;
    if (_isAnalyzing) return AiPublishState.analyzing;
    return AiPublishState.ready;
  }

  bool get _isPublishFlowCompleted {
    return _publishAiFlowStep == PublishOfferAiFlowStep.completed;
  }

  bool get _isVoiceFlowActive {
    return _publishAiFlowStep == PublishOfferAiFlowStep.voiceSelected ||
        _publishAiFlowStep == PublishOfferAiFlowStep.voiceAnalyzing;
  }

  bool get _isTextFlowActive {
    return _publishAiFlowStep == PublishOfferAiFlowStep.textSelected ||
        _publishAiFlowStep == PublishOfferAiFlowStep.textAnalyzing;
  }

  void _setPublishAiFlowStep(
    PublishOfferAiFlowStep nextStep, {
    String? reason,
  }) {
    if (_publishAiFlowStep == nextStep) return;
    debugPrint(
      '[PublishOfferAiFlow] step=$nextStep${reason == null ? '' : ' reason=$reason'}',
    );
    if (!mounted) {
      _publishAiFlowStep = nextStep;
      return;
    }
    setState(() {
      _publishAiFlowStep = nextStep;
    });
  }

  void _onSelectVoiceMethod() {
    if (_descriptionTapToEditPrimed) {
      setState(() {
        _descriptionTapToEditPrimed = false;
      });
      _descriptionFocusNode.unfocus();
    }
    _setPublishAiFlowStep(
      PublishOfferAiFlowStep.voiceSelected,
      reason: 'voice-tab-selected',
    );
  }

  Future<void> _onSelectTextMethod() async {
    if (mounted) {
      setState(() {
        _descriptionTapToEditPrimed = true;
      });
    } else {
      _descriptionTapToEditPrimed = true;
    }
    _setPublishAiFlowStep(
      PublishOfferAiFlowStep.textSelected,
      reason: 'text-tab-selected',
    );
    await WidgetsBinding.instance.endOfFrame;
    await _scrollToDescription();
  }

  void _markPublishAiFlowCompleted(String reason) {
    if (_descriptionTapToEditPrimed) {
      setState(() {
        _descriptionTapToEditPrimed = false;
      });
    }
    _setPublishAiFlowStep(PublishOfferAiFlowStep.completed, reason: reason);
  }

  void _restorePublishAiFlowAfterError({required bool fromVoice}) {
    _setPublishAiFlowStep(
      fromVoice
          ? PublishOfferAiFlowStep.voiceSelected
          : PublishOfferAiFlowStep.textSelected,
      reason: fromVoice ? 'voice-error' : 'text-error',
    );
  }

  String get _publishAiGuidanceText {
    if (_isListening) {
      return 'Enregistrement en cours. Parlez à l\'IA puis arrêtez pour lancer l\'analyse.';
    }

    switch (_publishAiFlowStep) {
      case PublishOfferAiFlowStep.chooseMethod:
        return 'Choisissez une méthode pour créer votre annonce.';
      case PublishOfferAiFlowStep.voiceSelected:
        return 'Parlez à l\'IA : elle remplira votre annonce automatiquement.';
      case PublishOfferAiFlowStep.voiceAnalyzing:
        return 'Analyse de votre annonce vocale en cours…';
      case PublishOfferAiFlowStep.textSelected:
        return 'Écrivez votre description, puis appuyez sur le bouton orange pour l\'améliorer avec l\'IA.';
      case PublishOfferAiFlowStep.textAnalyzing:
        return 'Amélioration de votre description en cours…';
      case PublishOfferAiFlowStep.completed:
        return 'Votre annonce est prête. Vous pouvez vérifier les informations avant publication.';
    }
  }

  Widget _buildPublishAiFlowHint() {
    if (_publishAiFlowStep == PublishOfferAiFlowStep.chooseMethod ||
        _publishAiFlowStep == PublishOfferAiFlowStep.voiceSelected ||
        _publishAiFlowStep == PublishOfferAiFlowStep.voiceAnalyzing) {
      return const SizedBox.shrink();
    }

    final isCompleted = _isPublishFlowCompleted;
    final isAnalyzing =
        _publishAiFlowStep == PublishOfferAiFlowStep.voiceAnalyzing ||
        _publishAiFlowStep == PublishOfferAiFlowStep.textAnalyzing;

    return AnimatedContainer(
      key: _publishAiFlowHintKey,
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFF2F8FF) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFD7E7FF)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAnalyzing
                ? Icons.auto_awesome_rounded
                : isCompleted
                ? Icons.check_circle_outline_rounded
                : Icons.tips_and_updates_outlined,
            color: isCompleted ? kPrestoBlue : const Color(0xFF5B6475),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _publishAiGuidanceText,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guidedSection({
    required Widget child,
    required bool isActive,
    required bool isDimmed,
    bool neonBorder = false,
  }) {
    final showNeon = isActive && neonBorder;
    final borderRadius = BorderRadius.circular(22);
    Widget sectionChild = child;

    if (isDimmed) {
      sectionChild = ClipRRect(
        borderRadius: borderRadius,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.45,
            0.45,
            0.45,
            0,
            0,
            0.45,
            0.45,
            0.45,
            0,
            0,
            0.45,
            0.45,
            0.45,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
            child: child,
          ),
        ),
      );
    }

    return IgnorePointer(
      ignoring: isDimmed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: isDimmed ? 0.72 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: showNeon ? const EdgeInsets.all(10) : EdgeInsets.zero,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: showNeon
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.88),
                    width: 1.15,
                  )
                : null,
            boxShadow: showNeon
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF6600).withValues(alpha: 0.18),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              sectionChild,
              if (isDimmed)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7280).withValues(alpha: 0.34),
                        borderRadius: borderRadius,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? normalizeDraftMissionDelay(String? rawUrgency) {
    final urgency = (rawUrgency ?? '').trim().toLowerCase();
    switch (urgency) {
      case 'immediat':
        return 'Urgent';
      case '24h':
        return 'Dans la journée';
      case 'demain':
        return 'Demain';
      case '48h':
        return 'Sous 48h';
      case '7j':
        return 'Cette semaine';
      case 'flexible':
        return 'À convenir';
      default:
        return null;
    }
  }

  bool transcriptMentionsBudget(String transcript) {
    final lower = transcript.toLowerCase();
    return RegExp(
          r'\b\d{2,5}(?:[.,]\d{1,2})?\s*(€|euros?)\b',
        ).hasMatch(lower) ||
        lower.contains('budget') ||
        lower.contains('tarif') ||
        lower.contains('prix') ||
        lower.contains('à négocier') ||
        lower.contains('a negocier');
  }

  bool transcriptMentionsUrgency(String transcript) {
    final lower = transcript.toLowerCase();
    return lower.contains('urgent') ||
        lower.contains('urgence') ||
        lower.contains("aujourd'hui") ||
        lower.contains('aujourd hui') ||
        lower.contains('demain') ||
        lower.contains('ce soir') ||
        lower.contains('48h') ||
        lower.contains('cette semaine') ||
        lower.contains('rapidement') ||
        lower.contains('dès que possible') ||
        lower.contains('des que possible') ||
        lower.contains('immédiat') ||
        lower.contains('immediat');
  }

  String? extractMissionDelayFromTranscript(String transcript) {
    final lower = transcript.toLowerCase();

    if (lower.contains('urgent') ||
        lower.contains('urgence') ||
        lower.contains('immédiat') ||
        lower.contains('immediat')) {
      return 'Urgent';
    }
    if (lower.contains("aujourd'hui") ||
        lower.contains('aujourd hui') ||
        lower.contains('dans la journée') ||
        lower.contains('dans la journee') ||
        lower.contains('24h')) {
      return 'Dans la journée';
    }
    if (lower.contains('demain')) {
      return 'Demain';
    }
    if (lower.contains('48h') || lower.contains('sous 48h')) {
      return 'Sous 48h';
    }
    if (lower.contains('cette semaine') ||
        lower.contains('dans la semaine') ||
        lower.contains('7 jours') ||
        lower.contains('7j')) {
      return 'Cette semaine';
    }
    if (lower.contains('à convenir') ||
        lower.contains('a convenir') ||
        lower.contains('quand vous pouvez') ||
        lower.contains('quand tu peux') ||
        lower.contains('flexible') ||
        lower.contains('pas urgent')) {
      return 'À convenir';
    }

    return null;
  }

  bool transcriptRequestsNegotiatedBudget(String transcript) {
    final lower = transcript.toLowerCase();
    return lower.contains('à négocier') ||
        lower.contains('a negocier') ||
        lower.contains('à discuter') ||
        lower.contains('a discuter') ||
        lower.contains('prix flexible') ||
        lower.contains('budget flexible');
  }

  double? extractBudgetAmountFromTranscript(String transcript) {
    final matches = RegExp(
      r'\b(\d{2,5}(?:[.,]\d{1,2})?)\s*(€|euros?)\b',
      caseSensitive: false,
    ).allMatches(transcript);

    for (final match in matches) {
      final raw = (match.group(1) ?? '').replaceAll(',', '.');
      final value = double.tryParse(raw);
      if (value != null && value > 0) {
        return value;
      }
    }

    return null;
  }

  /// Mots trop génériques pour compter comme information nouvelle dans une
  /// puce "details" (liaison, remplissage, localisation générique).
  static const Set<String> _kDetailFillerWords = {
    'avec',
    'pour',
    'dans',
    'chez',
    'vers',
    'sans',
    'sous',
    'entre',
    'plus',
    'tres',
    'tout',
    'toute',
    'tous',
    'toutes',
    'cette',
    'votre',
    'notre',
    'leur',
    'elle',
    'nous',
    'vous',
    'sont',
    'etre',
    'avoir',
    'faire',
    'merci',
    'besoin',
    'recherche',
    'recherchee',
    'demande',
    'secteur',
    'zone',
    'ville',
    'commune',
    'quartier',
  };

  String normalizeDetailText(String input) {
    const accents = 'àâäáãåçèéêëìíîïñòóôöõùúûüýÿ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyy';
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final idx = accents.indexOf(ch);
      if (idx >= 0) {
        buffer.write(plain[idx]);
      } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buffer.write(ch);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  List<String> significantDetailWords(String text) {
    return normalizeDetailText(text)
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4 && !_kDetailFillerWords.contains(w))
        .toList();
  }

  /// Deux mots comptent comme la même information s'ils sont identiques,
  /// si l'un contient l'autre (recherché/cherche) ou s'ils partagent une
  /// racine d'au moins 5 caractères (réparation/réparer).
  bool detailWordsMatch(String a, String b) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    final maxCommon = a.length < b.length ? a.length : b.length;
    var common = 0;
    while (common < maxCommon && a[common] == b[common]) {
      common++;
    }
    return common >= 5;
  }

  /// Filtre anti-doublon : écarte les puces "details" qui ne font que
  /// reformuler la description (ou une puce déjà retenue). Une puce est
  /// jugée redondante quand au moins 60 % de ses mots significatifs sont
  /// déjà présents dans le texte de référence.
  List<String> filterRedundantDetails(
    String description,
    List<String> details,
  ) {
    final referenceWords = significantDetailWords(description);
    final kept = <String>[];
    for (final detail in details) {
      final words = significantDetailWords(detail);
      if (words.isEmpty) continue;
      final matched = words
          .where((w) => referenceWords.any((d) => detailWordsMatch(w, d)))
          .length;
      if (matched / words.length >= 0.6) continue;
      kept.add(detail);
      referenceWords.addAll(words);
    }
    return kept;
  }

  String buildRichDraftDescription(Map<String, dynamic> draft) {
    final shortDescription =
        ((draft['description_courte'] ?? draft['description']) as String? ?? '')
            .trim();
    final details = (draft['details'] is List)
        ? (draft['details'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : const <String>[];
    final availabilities =
        ((draft['disponibilites'] ?? '') as String?)?.trim() ?? '';

    // Anti-doublon : le modèle peut renvoyer des puces qui paraphrasent la
    // transcription déjà présente dans la description — on ne garde que
    // celles qui apportent une information réellement nouvelle.
    final uniqueDetails = filterRedundantDetails(shortDescription, details);

    final lines = <String>[];
    if (shortDescription.isNotEmpty) {
      lines.add(shortDescription);
    }
    if (uniqueDetails.isNotEmpty) {
      lines.addAll(uniqueDetails.map((detail) => '- $detail'));
    }
    if (availabilities.isNotEmpty) {
      lines.add('Disponibilités : $availabilities');
    }
    return lines.join('\n').trim();
  }

  String firstNonEmptyDraftValue(
    Map<String, dynamic> draft,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = draft[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  void _applyRichDraftToForm(Map<String, dynamic> draft) {
    final title = firstNonEmptyDraftValue(draft, const [
      'title',
      'titre',
      'listingTitle',
      'offerTitle',
    ]);
    final description = buildRichDraftDescription(draft);
    final category = resolvePublishCategoryLabel(
      firstNonEmptyDraftValue(draft, const [
        'category',
        'categorie',
        'catégorie',
        'mainCategory',
      ]),
    );
    final rawLocation = firstNonEmptyDraftValue(draft, const [
      'city',
      'ville',
      'location',
      'localisation',
      'locality',
      'lieu',
      'commune',
      'address',
      'adresse',
      'rawLocation',
    ]);
    var detectedCity = firstNonEmptyDraftValue(draft, const [
      'city',
      'ville',
      'commune',
      'locality',
      'locationCity',
    ]);
    var detectedPostalCode = firstNonEmptyDraftValue(draft, const [
      'postalCode',
      'codePostal',
      'code_postal',
      'postal_code',
      'zipCode',
      'zipcode',
      'zip',
      'cp',
    ]);

    if (detectedCity.isEmpty && rawLocation.isNotEmpty) {
      detectedCity = rawLocation;
    }
    if (detectedPostalCode.isEmpty && rawLocation.isNotEmpty) {
      final cpFromLocation = extractPostalCodeFromTranscript(rawLocation);
      if ((cpFromLocation ?? '').isNotEmpty) {
        detectedPostalCode = cpFromLocation!;
      }
    }
    if (rawLocation.isNotEmpty && detectedCity.isNotEmpty) {
      final cityWithoutCp = detectedCity
          .replaceAll(RegExp(r'\b(97\d{3}|98\d{3}|\d{5})\b'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cityWithoutCp.isNotEmpty) {
        detectedCity = cityWithoutCp;
      }
    }

    final missionDelay = normalizeDraftMissionDelay(
      (draft['urgence'] ?? '').toString(),
    );
    final budget = draft['budget'] is Map
        ? Map<String, dynamic>.from(draft['budget'] as Map)
        : const <String, dynamic>{};
    final budgetMin = budget['min'];
    final budgetMax = budget['max'];
    final parsedMin = budgetMin is num ? budgetMin.toDouble() : null;
    final parsedMax = budgetMax is num ? budgetMax.toDouble() : null;
    final inferredBudget = parsedMin ?? parsedMax;
    final rawBudgetType = (budget['type'] ?? draft['budgetType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final wantsNegotiation =
        rawBudgetType == 'negotiable' ||
        rawBudgetType == 'a_negocier' ||
        rawBudgetType == 'à négocier';

    // The user-edited flags only block auto-fill when the field still holds
    // user input. If the field is empty (user typed then cleared, or never
    // typed), we still apply the AI suggestion — otherwise the IA button
    // appears broken because it never updates anything.
    bool canFillController(TextEditingController controller, bool editedFlag) {
      return controller.text.trim().isEmpty || !editedFlag;
    }

    setState(() {
      if (canFillController(_titleController, _titleEditedByUser) &&
          title.isNotEmpty) {
        _setControllerText(_titleController, title);
      }
      if (canFillController(_descriptionController, _descriptionEditedByUser) &&
          description.isNotEmpty) {
        _setControllerText(_descriptionController, description);
      }
      final hasNoCategory = (_category ?? '').trim().isEmpty;
      if ((hasNoCategory || !_categoryEditedByUser) &&
          category != null &&
          category.isNotEmpty) {
        _category = category;
        _selectedSubCategory = null;
        // Apply AI-detected sub-category if valid for the resolved category
        final rawSub = (draft['sous_categorie'] ?? '').toString().trim();
        if (rawSub.isNotEmpty) {
          final available =
              kCategorySubcategories[category] ?? const <String>[];
          if (available.contains(rawSub)) {
            _selectedSubCategory = rawSub;
          }
        }
      }
      if ((_missionDelay == null || !_delayEditedByUser) &&
          missionDelay != null) {
        _missionDelay = missionDelay;
        _isUrgent = missionDelay == 'Urgent';
      }
      if (canFillController(_budgetController, _budgetEditedByUser)) {
        if (inferredBudget != null) {
          _budgetType = 'Fixe';
          final formattedBudget = inferredBudget % 1 == 0
              ? inferredBudget.toInt().toString()
              : inferredBudget.toStringAsFixed(2);
          _setControllerText(_budgetController, formattedBudget);
        } else if (wantsNegotiation) {
          _budgetType = 'À négocier';
          _setControllerText(_budgetController, '');
        }
      }
    });

    _applyDetectedCityData(
      city: detectedCity,
      postalCode: detectedPostalCode,
      departmentHint:
          (draft['department'] ??
                  draft['departement'] ??
                  draft['departmentName'] ??
                  draft['departmentCode'] ??
                  '')
              .toString(),
      regionHint:
          (draft['region'] ?? draft['regionName'] ?? draft['regionCode'] ?? '')
              .toString(),
      locationHint: rawLocation,
    );
    _applyKeywordCategoryPairFromText('$title\n$description');
    // Guarantee the publish button re-evaluates after AI sets state variables
    // (_category, _missionDelay, _budgetType) that have no controller listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recompute();
    });
  }

  // ✅ Extraction rapide CP (FR + DROM) depuis la transcription
  String? extractPostalCodeFromTranscript(String transcript) {
    final t = transcript;
    // 5 chiffres métropole + 97x/98x (DROM/COM) acceptés aussi (souvent 5 chiffres au final)
    final m = RegExp(r'\b(97[0-9]{3}|98[0-9]{3}|[0-9]{5})\b').firstMatch(t);
    return m?.group(1);
  }

  // ✅ Extraction ville: soit via CP (fiable), soit via motif "à <ville>"
  CityRecord? _extractCityRecordFromTranscript(
    String transcript, {
    String? cp,
  }) {
    if (cp != null && cp.trim().isNotEmpty) {
      return FrenchCityPostalValidator.instance.resolveCanonicalCity(
        city: '',
        postalCode: cp.trim(),
      );
    }

    // ✅ FIX: raw string + apostrophes => utiliser guillemets doubles
    final m = RegExp(
      r"\b(?:a|à|sur|vers|près de|proche de)\s+([A-Za-zÀ-ÖØ-öø-ÿ''\-\s]{2,40})\b",
      caseSensitive: false,
    ).firstMatch(transcript);

    final rawCity = m?.group(1)?.trim();
    if (rawCity == null || rawCity.isEmpty) return null;

    return FrenchCityPostalValidator.instance.resolveCanonicalCity(
      city: rawCity,
      postalCode: '',
    );
  }

  String? resolvePublishCategoryLabel(String? rawCategory) {
    final canonical = canonicalizeOfferCategory(rawCategory);
    if (canonical == null || canonical.trim().isEmpty) return null;

    final normalizedCanonical = normalizeOfferText(canonical);
    for (final category in _categories) {
      if (normalizeOfferText(category) == normalizedCanonical) {
        return category;
      }
    }
    // Secondary pass: match against kCategories, then find the corresponding
    // dropdown key — guards against ligature divergence (e.g. Main-d'oeuvre vs
    // Main-d'œuvre) between kCategorySubcategories and kCategories.
    for (final kCat in kCategories) {
      if (normalizeOfferText(kCat) == normalizedCanonical) {
        for (final category in _categories) {
          if (normalizeOfferText(category) == normalizeOfferText(kCat)) {
            return category;
          }
        }
      }
    }
    return null;
  }

  CityRecord? _resolveCanonicalCityRecord({String? city, String? postalCode}) {
    return FrenchCityPostalValidator.instance.resolveCanonicalCity(
      city: city,
      postalCode: postalCode,
    );
  }

  void _canonicalizeLocationInputs() {
    final best = _resolveCanonicalCityRecord(
      city: _locationController.text,
      postalCode: _postalCodeController.text,
    );
    if (best == null) return;

    final sameCity = _locationController.text.trim() == best.name;
    final samePostalCode = _postalCodeController.text.trim() == best.cp;
    if (sameCity && samePostalCode) return;

    _applyCity(best, forceApply: true);
  }

  String normalizeAiGeoHint(String value) {
    return normalizeLocationLookupKey(value)
        .replaceAll(RegExp(r'\bdepartement\b'), '')
        .replaceAll(RegExp(r'\bdepartment\b'), '')
        .replaceAll(RegExp(r'\bregion\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool geoCommuneMatchesAiHint(
    GeoApiGouvCommune commune, {
    required String departmentHint,
    required String regionHint,
    required String locationHint,
  }) {
    final dept = commune.departmentCode.trim();
    final region = commune.regionCode.trim();

    final hints = <String>[
      departmentHint,
      regionHint,
      locationHint,
    ].map(normalizeAiGeoHint).where((v) => v.isNotEmpty).toList();

    if (hints.isEmpty) {
      return true;
    }

    final departmentAliases = <String, Set<String>>{
      '971': {'971', 'guadeloupe', 'gwada'},
      '972': {'972', 'martinique'},
      '973': {'973', 'guyane', 'guyane francaise'},
      '974': {'974', 'reunion', 'la reunion'},
      '976': {'976', 'mayotte'},
    };

    final regionAliases = <String, Set<String>>{
      '01': {'01', 'guadeloupe', 'gwada'},
      '02': {'02', 'martinique'},
      '03': {'03', 'guyane', 'guyane francaise'},
      '04': {'04', 'reunion', 'la reunion'},
      '06': {'06', 'mayotte'},
    };

    bool hintMatchesAliases(String hint, Set<String> aliases) {
      return aliases.any((alias) => hint == alias || hint.contains(alias));
    }

    for (final hint in hints) {
      if (hint == dept || hint.contains(dept)) return true;
      if (hint == region || hint.contains(region)) return true;

      final deptAliases = departmentAliases[dept];
      if (deptAliases != null && hintMatchesAliases(hint, deptAliases)) {
        return true;
      }

      final regAliases = regionAliases[region];
      if (regAliases != null && hintMatchesAliases(hint, regAliases)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _resolveAiCityWithGeoApiGouv({
    required String rawCity,
    required String rawPostalCode,
    required String departmentHint,
    required String regionHint,
    required String locationHint,
  }) async {
    final city = rawCity.trim();
    final postalCode = rawPostalCode.trim();

    if (city.isEmpty) return;

    try {
      final communes = postalCode.length == 5
          ? await _geoApiGouvService.findCommunesByPostalCode(postalCode)
          : await _geoApiGouvService.searchCommunesByName(city);

      if (!mounted || communes.isEmpty) return;

      final normalizedCity = normalizeLocationLookupKey(city);

      final candidates = communes.where((commune) {
        final normalizedCommune = normalizeLocationLookupKey(commune.name);

        final nameMatches =
            normalizedCommune == normalizedCity ||
            normalizedCommune.contains(normalizedCity) ||
            normalizedCity.contains(normalizedCommune);

        if (!nameMatches) return false;

        return geoCommuneMatchesAiHint(
          commune,
          departmentHint: departmentHint,
          regionHint: regionHint,
          locationHint: locationHint,
        );
      }).toList();

      final selected = candidates.isNotEmpty
          ? candidates.first
          : communes.first;
      final resolvedCp = selected.primaryPostalCode.trim();

      if (resolvedCp.isEmpty) return;

      setState(() {
        if (_locationController.text.trim().isEmpty ||
            normalizeLocationLookupKey(_locationController.text) !=
                normalizeLocationLookupKey(selected.name)) {
          _setControllerText(_locationController, selected.name);
        }

        if (!_postalCodeEditedByUser ||
            _postalCodeController.text.trim().isEmpty) {
          _setControllerText(_postalCodeController, resolvedCp);
        }

        _selectedPhoneCountryCode = countryCodeForDept(selected.departmentCode);
      });

      if (kDebugMode) {
        debugPrint(
          '[Publish] IA Geo resolved city="$city" deptHint="$departmentHint" '
          'regionHint="$regionHint" -> ${selected.name} $resolvedCp',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Publish] IA Geo resolve failed: $e');
      }
    }
  }

  void _applyDetectedCityData({
    String? city,
    String? postalCode,
    String? departmentHint,
    String? regionHint,
    String? locationHint,
  }) {
    final rawCity = (city ?? '').trim();
    final rawPostalCode = (postalCode ?? '').trim();

    final best = _resolveCanonicalCityRecord(
      city: rawCity,
      postalCode: rawPostalCode,
    );

    if (best != null) {
      _applyCity(best);
      return;
    }

    _resolveAiCityWithGeoApiGouv(
      rawCity: rawCity,
      rawPostalCode: rawPostalCode,
      departmentHint: (departmentHint ?? '').trim(),
      regionHint: (regionHint ?? '').trim(),
      locationHint: (locationHint ?? '').trim(),
    );

    // Ne jamais injecter une ville/CP IA non resolus dans le formulaire.
    // Sinon l'utilisateur voit des champs remplis mais invalides, puis se
    // retrouve bloque plus tard par la validation "ville/CP".
    if (kDebugMode && (rawCity.isNotEmpty || rawPostalCode.isNotEmpty)) {
      debugPrint(
        '[Publish] IA location ignored: unresolved city="$rawCity" postalCode="$rawPostalCode"',
      );
    }
  }

  void _applyKeywordCategoryPairFromText(String text) {
    final match = resolvePublishCategoryPairFromText(text);
    if (match == null) return;

    final currentCategory = (_category ?? '').trim();
    final currentSubCategory = (_selectedSubCategory ?? '').trim();
    final sameCategory =
        currentCategory.isNotEmpty &&
        normalizeOfferText(currentCategory) ==
            normalizeOfferText(match.category);
    final canSetCategory = !_categoryEditedByUser && currentCategory.isEmpty;
    final canSetSubCategory =
        !_categoryEditedByUser &&
        currentSubCategory.isEmpty &&
        (canSetCategory || sameCategory);
    final canSetTitle =
        !_titleEditedByUser &&
        _titleController.text.trim().isEmpty &&
        (match.suggestedTitle ?? '').trim().isNotEmpty;

    if (!canSetCategory && !canSetSubCategory && !canSetTitle) {
      return;
    }

    setState(() {
      if (canSetTitle) {
        _setControllerText(_titleController, match.suggestedTitle!.trim());
      }

      if (canSetCategory) {
        _category = match.category;
        _selectedSubCategory = null;
      }

      final effectiveCategory = (_category ?? '').trim();
      final availableSubcategories =
          kCategorySubcategories[match.category] ?? const <String>[];
      if (currentSubCategory.isEmpty &&
          normalizeOfferText(effectiveCategory) ==
              normalizeOfferText(match.category) &&
          availableSubcategories.contains(match.subCategory)) {
        _selectedSubCategory = match.subCategory;
      }
    });
  }

  /// Remplissage immédiat (latence perçue ↓) dès que la transcription est prête.
  /// L'IA pourra ensuite affiner et remplacer.
  void _applyFastDraftFromTranscript(String transcript) {
    final t = transcript.trim();
    if (t.isEmpty) return;

    bool canFillController(TextEditingController controller, bool editedFlag) {
      return controller.text.trim().isEmpty || !editedFlag;
    }

    if (canFillController(_descriptionController, _descriptionEditedByUser)) {
      _setControllerText(_descriptionController, t);
    }

    if (canFillController(_titleController, _titleEditedByUser)) {
      final firstLine = t.split('\n').first.trim();
      final firstSentence = firstLine.split(RegExp(r'[.!?]')).first.trim();
      final candidate = (firstSentence.isNotEmpty ? firstSentence : firstLine);

      final title = candidate.length > 72
          ? '${candidate.substring(0, 72).trim()}…'
          : candidate;
      if (title.isNotEmpty) {
        _setControllerText(_titleController, title);
      }
    }

    if (canFillController(_postalCodeController, _postalCodeEditedByUser)) {
      final cp = extractPostalCodeFromTranscript(t);
      if (cp != null && cp.isNotEmpty) {
        _setControllerText(_postalCodeController, cp);
      }
    }

    final effectiveCp = _postalCodeController.text.trim().isEmpty
        ? null
        : _postalCodeController.text.trim();

    if (canFillController(_locationController, _locationEditedByUser)) {
      final cityRec = _extractCityRecordFromTranscript(t, cp: effectiveCp);
      if (cityRec != null) {
        _setControllerText(_locationController, cityRec.name);

        if (canFillController(_postalCodeController, _postalCodeEditedByUser) &&
            _postalCodeController.text.trim().isEmpty &&
            cityRec.cp.isNotEmpty) {
          _setControllerText(_postalCodeController, cityRec.cp);
        }

        // bonus cohérence UI: indicatif selon dept (déjà présent dans le code)
        if (!mounted) return;
        setState(() {
          _selectedPhoneCountryCode = countryCodeForDept(cityRec.dept);
        });
      }
    }

    final inferredMissionDelay = extractMissionDelayFromTranscript(t);
    if ((_missionDelay == null || !_delayEditedByUser) &&
        inferredMissionDelay != null) {
      setState(() {
        _missionDelay = inferredMissionDelay;
        _isUrgent = inferredMissionDelay == 'Urgent';
      });
    }

    if (canFillController(_budgetController, _budgetEditedByUser)) {
      if (transcriptRequestsNegotiatedBudget(t)) {
        setState(() {
          _budgetType = 'À négocier';
          _setControllerText(_budgetController, '');
        });
      } else {
        final inferredBudget = extractBudgetAmountFromTranscript(t);
        if (inferredBudget != null) {
          final formattedBudget = inferredBudget % 1 == 0
              ? inferredBudget.toInt().toString()
              : inferredBudget.toStringAsFixed(2);
          setState(() {
            _budgetType = 'Fixe';
            _setControllerText(_budgetController, formattedBudget);
          });
        }
      }
    }

    _applyKeywordCategoryPairFromText(t);
    // Same guarantee as _applyRichDraftToForm: state-only fields (_missionDelay,
    // _budgetType) don't trigger controller listeners, so force a recompute.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recompute();
    });
  }

  /// Apply draft payload returned by the publish IA pipeline.
  void _applyDraftToForm(Map<String, dynamic> draft) {
    _applyRichDraftToForm(draft);
  }

  @override
  void initState() {
    // PRESTO_AUTH_PAGE_GUARD_PUBLICATION
    // Désactivé : l'onglet Publier une offre doit s'ouvrir sans afficher la connexion.

    // La vérification de connexion doit rester au moment de la publication.

    //

    //     WidgetsBinding.instance.addPostFrameCallback((_) async {

    //       if (!mounted) return;

    // Désactivé : ne pas afficher la connexion à l'ouverture de l'onglet Publier.
    // //       await AuthGuard.requireVerifiedEmail(context);

    //     });

    super.initState();
    unawaited(_adminAudioRuntimeStore.ensureInitialized());
    unawaited(_loadMarketplacePhotoLimit());
    unawaited(_prefillPublishFromProfile());
    unawaited(_refreshAdminAudioRuntimeAccess());

    _scrollController.addListener(() {
      widget.onScroll?.call(_scrollController.offset);
    });

    _titleController.addListener(_recompute);
    _titleController.addListener(_handlePublishTitleChanged);
    _descriptionController.addListener(_recompute);
    _descriptionController.addListener(_handlePublishDescriptionChanged);
    _locationController.addListener(_recompute);
    _locationController.addListener(_handlePublishLocationChanged);
    _postalCodeController.addListener(_handlePublishPostalCodeChanged);
    _phoneController.addListener(_recompute);
    _budgetController.addListener(_recompute);
    _budgetController.addListener(_handlePublishBudgetChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
    FocusManager.instance.addListener(_onFocusManagerChange);
  }

  void _onFocusManagerChange() {
    if (FocusManager.instance.primaryFocus == null) {
      _handlePublishKeyboardDismissed();
    }
    if (!_showDarkOverlay) return;
    if (FocusManager.instance.primaryFocus == null) return;
    if (!mounted) return;
    setState(() => _showDarkOverlay = false);
  }

  // Quand le clavier se ferme (plus aucun champ focus) pendant l'étape de
  // description guidée par l'IA, la position de scroll avait été calculée
  // pour la hauteur réduite (clavier ouvert). Une fois le clavier rétracté,
  // on relance ensureVisible sur la nouvelle hauteur pour que le bouton IA
  // et le reste du contenu réapparaissent au lieu de laisser un espace vide.
  void _handlePublishKeyboardDismissed() {
    if (_publishAiFlowStep != PublishOfferAiFlowStep.textSelected) return;
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      final ctx = _descriptionFieldKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  Future<void> _loadMarketplacePhotoLimit() async {
    try {
      await _marketplaceRemoteConfigService.initialize();
      final configuredLimit = _marketplaceRemoteConfigService.listingMaxPhotos;
      final normalizedLimit = configuredLimit < _minimumMaxListingPhotos
          ? _minimumMaxListingPhotos
          : configuredLimit > _publishPhotoHardLimit
          ? _publishPhotoHardLimit
          : configuredLimit;
      if (!mounted || normalizedLimit == _maxListingPhotos) {
        return;
      }
      setState(() {
        _maxListingPhotos = normalizedLimit;
      });
    } catch (_) {
      // Garde la valeur par défaut si la remote config n'est pas disponible.
    }
  }

  int get _visiblePhotoTileCount {
    if (_selectedPhotos.length >= _maxListingPhotos) {
      return _maxListingPhotos;
    }
    return _selectedPhotos.length + 1;
  }

  bool isValidPhoneFR(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'\s+'), '');
    if (sanitized.isEmpty) return false;

    if (sanitized.startsWith('+')) {
      return RegExp(r'^\+[0-9]{8,15}$').hasMatch(sanitized);
    }

    return RegExp(r'^[0-9]{6,15}$').hasMatch(sanitized);
  }

  String firstNonEmptyPublishPhone(
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

  void _applyPublishPhoneFromProfile(
    String rawPhone, {
    String? explicitCountryCode,
  }) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    final allDigits = compact.replaceAll(RegExp(r'\D'), '');

    final normalizedExplicitCode = (explicitCountryCode ?? '').trim();
    final knownCodes = kPhoneCountryCodes
        .map((country) => country.code)
        .toList();

    String selectedCode = normalizedExplicitCode;
    if (selectedCode.isEmpty || !knownCodes.contains(selectedCode)) {
      for (final code in knownCodes) {
        if (compact.startsWith(code)) {
          selectedCode = code;
          break;
        }
      }
    }

    if (selectedCode.isEmpty) {
      selectedCode = _selectedPhoneCountryCode;
    }
    if (!knownCodes.contains(selectedCode)) {
      selectedCode = '+33';
    }

    final codeDigits = selectedCode.replaceAll(RegExp(r'\D'), '');
    var localDigits = allDigits;
    if (codeDigits.isNotEmpty && allDigits.startsWith(codeDigits)) {
      localDigits = allDigits.substring(codeDigits.length);
    }

    _selectedPhoneCountryCode = selectedCode;
    _phoneController.text = localDigits.isNotEmpty ? localDigits : trimmed;
  }

  Future<void> _prefillPublishFromProfile() async {
    final phoneNeeded = _phoneController.text.trim().isEmpty;
    final locationNeeded =
        !_locationEditedByUser &&
        !_postalCodeEditedByUser &&
        _locationController.text.trim().isEmpty &&
        _postalCodeController.text.trim().isEmpty;
    if (!phoneNeeded && !locationNeeded) return;

    final user = _authOrNull?.currentUser;
    if (user == null) return;

    final firestore = _firestoreOrNull;
    if (firestore == null) return;

    final userRef = firestore.collection('users').doc(user.uid);

    try {
      try {
        await UserProfileBootstrapService.prepareProfileFirestoreAccess(
          user: user,
          forceRefreshToken: true,
          forceRefreshAppCheckToken: true,
        );
      } catch (error) {
        debugPrint(
          '[Publish] Préparation accès profil échouée, fallback cache/Auth: $error',
        );
      }

      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        doc = await userRef
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 5));
      } catch (serverError) {
        debugPrint(
          '[Publish] Lecture serveur profil impossible, fallback cache: $serverError',
        );
        try {
          doc = await userRef
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 3));
        } catch (cacheError) {
          debugPrint(
            '[Publish] Lecture cache profil impossible, fallback Auth: $cacheError',
          );
        }
      }

      final data = doc?.data();

      if (phoneNeeded &&
          data != null &&
          mounted &&
          _phoneController.text.trim().isEmpty) {
        final rawPhone = firstNonEmptyPublishPhone(
          data,
          const ['phone', 'phoneNumber', 'phone_number'],
          fallbackValues: <String>[user.phoneNumber ?? ''],
        );
        final phoneCountryCode = data['phoneCountryCode']?.toString().trim();
        if (rawPhone.isNotEmpty) {
          setState(() {
            _applyPublishPhoneFromProfile(
              rawPhone,
              explicitCountryCode: phoneCountryCode,
            );
          });
          _recompute();
        }
      }

      if (locationNeeded && data != null && mounted) {
        final location = ProfileReadinessChecker.resolveLocation(data);
        final profileCity = location.city.trim();
        final profilePostalCode = location.postalCode.trim();

        if (profileCity.isNotEmpty || profilePostalCode.isNotEmpty) {
          CityRecord? cityRecord;
          if (profilePostalCode.isNotEmpty) {
            cityRecord = FrenchCityPostalValidator.instance
                .resolveCanonicalCity(
                  city: profileCity,
                  postalCode: profilePostalCode,
                );
          }
          if (cityRecord == null && profileCity.isNotEmpty) {
            final matches = FrenchCityPostalValidator.instance
                .searchSuggestions(
                  profileCity,
                  postalCodeHint: profilePostalCode,
                  limit: 5,
                );
            for (final candidate in matches) {
              if (profilePostalCode.isEmpty ||
                  candidate.cp == profilePostalCode) {
                cityRecord = candidate;
                break;
              }
            }
          }

          final resolvedCity = cityRecord?.name.trim().isNotEmpty == true
              ? cityRecord!.name.trim()
              : profileCity;
          final resolvedPostalCode = cityRecord?.cp.trim().isNotEmpty == true
              ? cityRecord!.cp.trim()
              : profilePostalCode;

          if (mounted) {
            var changed = false;
            setState(() {
              if (!_locationEditedByUser &&
                  _locationController.text.trim().isEmpty &&
                  resolvedCity.isNotEmpty) {
                _setControllerText(_locationController, resolvedCity);
                changed = true;
              }
              if (!_postalCodeEditedByUser &&
                  _postalCodeController.text.trim().isEmpty &&
                  resolvedPostalCode.isNotEmpty) {
                _setControllerText(_postalCodeController, resolvedPostalCode);
                changed = true;
              }
              final dept =
                  cityRecord?.dept ??
                  departmentFromPostalCode(resolvedPostalCode);
              if (dept != null && dept.isNotEmpty) {
                _selectedPhoneCountryCode = countryCodeForDept(dept);
              }
              final region = cityRecord?.region;
              if (region != null && region.isNotEmpty) {
              }
            });
            if (changed) _recompute();
          }
        }
      }
    } catch (error) {
      debugPrint('[Publish] Préremplissage profil impossible: $error');
    }
  }

  double? parseBudget(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  Widget _requiredLabel(String text) {
    final theme = Theme.of(context);
    final base =
        theme.inputDecorationTheme.labelStyle ??
        theme.textTheme.bodyLarge ??
        const TextStyle(fontSize: 16, color: Colors.black87);
    final baseColor = base.color ?? Colors.black87;

    return RichText(
      text: TextSpan(
        style: base.copyWith(color: baseColor),
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  bool _showAiPendingForController(TextEditingController controller) {
    return _isAnalyzing && controller.text.trim().isEmpty;
  }

  bool get _showAiPendingForCategory {
    final noCategory = _category == null || _category!.trim().isEmpty;
    return noCategory && (_isAnalyzing || _isClassifyingPhoto);
  }

  Widget _withAiPendingOverlay({
    required Widget child,
    required bool showPending,
    Alignment alignment = Alignment.centerRight,
    EdgeInsets padding = const EdgeInsets.only(right: 42),
  }) {
    if (!showPending) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: alignment,
              child: Padding(
                padding: padding,
                child: const _FieldPendingDots(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? validatePublishTitle(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Merci de saisir un titre';
    }
    if (trimmed.length < 10) {
      return 'Le titre doit contenir au moins 10 caractères';
    }
    if (trimmed.length > 120) {
      return 'Le titre doit contenir au maximum 120 caractères';
    }
    return null;
  }

  String? validatePublishDescription(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Merci de décrire votre besoin';
    }
    if (trimmed.length < 30) {
      return 'La description doit contenir au moins 30 caractères';
    }
    if (trimmed.length > 4000) {
      return 'La description doit contenir au maximum 4000 caractères';
    }
    return null;
  }

  String? _validateCanonicalCity(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Merci de saisir une ville';
    }

    final result = FrenchCityPostalValidator.instance.validate(
      city: trimmed,
      postalCode: _postalCodeController.text,
    );
    if (!result.isKnownCity) {
      return 'Choisissez une ville dans la liste ou vérifiez l\'orthographe.';
    }
    return null;
  }

  String? _validatePostalCode(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (!RegExp(r'^(97\d{3}|98\d{3}|\d{5})$').hasMatch(trimmed)) {
      return 'Code postal invalide';
    }

    final result = FrenchCityPostalValidator.instance.validate(
      city: _locationController.text,
      postalCode: trimmed,
    );
    if (!result.isKnownCity) {
      return null;
    }
    if (!result.postalCodeMatches) {
      return 'Le code postal ne correspond pas à cette ville.';
    }
    return null;
  }

  String translatePublishIssue(String issue) {
    final trimmed = issue.trim();
    if (trimmed == 'Title must contain at least 10 characters') {
      return 'Le titre doit contenir au moins 10 caractères.';
    }
    if (trimmed == 'Title must contain at most 120 characters') {
      return 'Le titre doit contenir au maximum 120 caractères.';
    }
    if (trimmed == 'Description must contain at least 30 characters') {
      return 'La description doit contenir au moins 30 caractères.';
    }
    if (trimmed == 'Description must contain at most 4000 characters') {
      return 'La description doit contenir au maximum 4000 caractères.';
    }
    if (trimmed == 'Price must be a positive number') {
      return 'Le budget doit être supérieur ou égal à 0.';
    }
    if (trimmed == 'categoryId is required') {
      return 'Choisissez une catégorie valide.';
    }
    if (trimmed == 'Category is invalid or inactive' ||
        trimmed == 'category is invalid or inactive') {
      return "La catégorie sélectionnée n'est plus disponible. Choisissez une autre catégorie.";
    }
    if (trimmed == 'cityId is required') {
      return 'Choisissez une ville valide.';
    }
    if (trimmed == 'City is invalid or inactive' ||
        trimmed == 'city is invalid or inactive') {
      return "La ville sélectionnée n'est plus disponible. Choisissez une ville valide dans la liste.";
    }
    if (trimmed == 'reCAPTCHA assessment rejected the listing submission') {
      return 'La vérification anti-abus a échoué. Réessaie dans quelques secondes.';
    }
    if (trimmed ==
        'La vérification anti-abus est indisponible pour le moment. Recharge la page puis réessaie.') {
      return 'La vérification anti-abus est indisponible pour le moment. Recharge la page puis réessaie.';
    }
    if (trimmed == 'Authentication required.' || trimmed == 'unauthenticated') {
      return 'Connecte-toi pour utiliser la dictée.';
    }
    if (trimmed == 'storagePath does not belong to authenticated user.' ||
        trimmed == 'permission-denied') {
      return 'Cette dictée ne correspond plus à ta session. Recharge la page puis réessaie.';
    }
    if (trimmed == 'Audio file is empty.') {
      return 'Le micro n\'a capté aucun son exploitable. Réessaie en parlant plus près du micro.';
    }
    if (trimmed.startsWith('Audio trop court/faible')) {
      return 'L\'audio est trop court pour être transcrit. Parle un peu plus longtemps puis réessaie.';
    }
    if (trimmed.startsWith('Type audio invalide')) {
      return 'Le format audio envoyé au serveur est invalide. Recharge la page puis réessaie.';
    }
    if (trimmed == 'Too many listing submissions, please retry later') {
      return 'Trop de tentatives de publication en peu de temps. Réessaie plus tard.';
    }
    if (trimmed == 'Draft not found') {
      return 'Le brouillon de publication est introuvable. Relance la publication.';
    }
    if (trimmed == 'You do not own this draft') {
      return 'Ce brouillon ne correspond pas à ton compte connecté.';
    }
    if (trimmed.startsWith('Photo #') &&
        trimmed.endsWith('must be processed as WebP before submission')) {
      final number = RegExp(r'Photo #(\d+)').firstMatch(trimmed)?.group(1);
      return number == null
          ? 'Une photo doit être retraitée avant publication. Réessayez.'
          : 'La photo $number doit être retraitée avant publication. Réessayez.';
    }
    if (trimmed == 'Draft payload is invalid') {
      return 'Le formulaire de publication est invalide.';
    }
    return trimmed;
  }

  String formatPublishError(Object error) {
    if (error is FirebaseFunctionsException) {
      final details = error.details;
      if (details is Map) {
        final rawIssues = details['issues'];
        if (rawIssues is List) {
          final issues = rawIssues
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .map(translatePublishIssue)
              .toList(growable: false);
          if (issues.isNotEmpty) {
            return issues.join(' ');
          }
        }
      }

      final message = (error.message ?? error.code).trim();
      return translatePublishIssue(message);
    }

    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '');
  }

  bool _requiredOk() {
    final titleOk = validatePublishTitle(_titleController.text) == null;
    final descOk =
        validatePublishDescription(_descriptionController.text) == null;
    final cityOk = _locationController.text.trim().isNotEmpty;
    final catOk = (_category ?? '').trim().isNotEmpty;
    const subOk = true;
    final delayOk = (_missionDelay ?? '').trim().isNotEmpty;
    final phoneOk = isValidPhoneFR(_phoneController.text);
    final budgetOk = _budgetType == 'À négocier'
        ? true
        : () {
            final b = parseBudget(_budgetController.text);
            return b != null && b > 0;
          }();

    return titleOk &&
        descOk &&
        cityOk &&
        catOk &&
        subOk &&
        delayOk &&
        phoneOk &&
        budgetOk;
  }

  Iterable<String> get _requiredPublishFieldOrder => const <String>[
    'title',
    'category',
    'description',
    'city',
    'phone',
    'delay',
    'budget',
  ];

  GlobalKey _publishFieldKeyFor(String fieldId) {
    switch (fieldId) {
      case 'title':
        return _titleFieldKey;
      case 'category':
        return _categoryFieldKey;
      case 'description':
        return _descriptionFieldKey;
      case 'city':
        return _cityFieldKey;
      case 'phone':
        return _phoneFieldKey;
      case 'delay':
        return _delayFieldKey;
      case 'budget':
        return _budgetFieldKey;
      default:
        return GlobalKey();
    }
  }

  String publishFieldLabel(String fieldId) {
    switch (fieldId) {
      case 'title':
        return 'titre';
      case 'category':
        return 'catégorie';
      case 'description':
        return 'description';
      case 'city':
        return 'ville';
      case 'phone':
        return 'téléphone';
      case 'delay':
        return 'délai';
      case 'budget':
        return 'budget';
      default:
        return fieldId;
    }
  }

  bool _isPublishFieldInvalid(String fieldId) {
    switch (fieldId) {
      case 'title':
        return validatePublishTitle(_titleController.text) != null;
      case 'category':
        return (_category ?? '').trim().isEmpty;
      case 'description':
        return validatePublishDescription(_descriptionController.text) != null;
      case 'city':
        return _validateCanonicalCity(_locationController.text) != null;
      case 'phone':
        return !isValidPhoneFR(_phoneController.text);
      case 'delay':
        return (_missionDelay ?? '').trim().isEmpty;
      case 'budget':
        if (_budgetType == 'À négocier') return false;
        final budget = parseBudget(_budgetController.text);
        return budget == null || budget <= 0;
      default:
        return false;
    }
  }

  List<String> _missingPublishFieldLabels() {
    return _requiredPublishFieldOrder
        .where(_isPublishFieldInvalid)
        .map(publishFieldLabel)
        .toList(growable: false);
  }

  Future<void> _scrollToDescription() async {
    final shouldShowHintFirst =
        _publishAiFlowStep == PublishOfferAiFlowStep.textSelected ||
        _publishAiFlowStep == PublishOfferAiFlowStep.textAnalyzing;
    BuildContext? hintCtx = _publishAiFlowHintKey.currentContext;
    if (shouldShowHintFirst && hintCtx == null) {
      await WidgetsBinding.instance.endOfFrame;
      hintCtx = _publishAiFlowHintKey.currentContext;
    }
    final descriptionCtx = _descriptionFieldKey.currentContext;
    final targetCtx = shouldShowHintFirst && hintCtx != null
        ? hintCtx
        : descriptionCtx;
    if (targetCtx == null) return;

    await Scrollable.ensureVisible(
      targetCtx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: shouldShowHintFirst ? 0.08 : 0.5,
    );
    // Positionne le curseur au début pour que la suggestion soit visible en italique
    _descriptionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _descriptionController.text.length),
    );
    if (_descriptionTapToEditPrimed) {
      final focusCtx = descriptionCtx ?? targetCtx;
      FocusScope.of(focusCtx).requestFocus(_descriptionFocusNode);
    }
  }

  void _unlockDescriptionEditing() {
    if (!_descriptionTapToEditPrimed) return;
    setState(() {
      _descriptionTapToEditPrimed = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _descriptionFocusNode.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  Future<void> _scrollToFirstInvalidPublishField() async {
    for (final fieldId in _requiredPublishFieldOrder) {
      if (!_isPublishFieldInvalid(fieldId)) continue;
      _triggerPublishFieldShake(fieldId);
      final targetContext = _publishFieldKeyFor(fieldId).currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.18,
        );
      }
      break;
    }
  }

  void _triggerPublishFieldShake(String fieldId) {
    final tick = _publishShakeTick + 1;
    if (mounted) {
      setState(() {
        _publishShakeTick = tick;
        _shakingPublishFieldId = fieldId;
      });
    }

    Future<void>.delayed(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      if (_publishShakeTick != tick) return;
      setState(() {
        _shakingPublishFieldId = null;
      });
    });
  }

  Widget _withPublishFieldHighlight({
    required String fieldId,
    required Widget child,
  }) {
    final invalid = _attemptedSubmit && _isPublishFieldInvalid(fieldId);
    final isShaking = _shakingPublishFieldId == fieldId;
    final useDarkStyle = invalid && _showDarkOverlay;

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('publish-field-$fieldId-$_publishShakeTick'),
      tween: Tween<double>(begin: 0, end: isShaking ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      builder: (context, value, animatedChild) {
        final dx = isShaking
            ? math.sin(value * math.pi * 6) * (1 - value) * 12
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: animatedChild);
      },
      child: AnimatedContainer(
        key: _publishFieldKeyFor(fieldId),
        duration: const Duration(milliseconds: 180),
        padding: invalid ? const EdgeInsets.all(6) : EdgeInsets.zero,
        decoration: invalid
            ? BoxDecoration(
                color: useDarkStyle
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: useDarkStyle ? Colors.white : const Color(0xFFDC2626),
                  width: useDarkStyle ? 2.0 : 1.4,
                ),
                boxShadow: useDarkStyle
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Color(0x1FDC2626),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
              )
            : null,
        child: child,
      ),
    );
  }

  void _recompute() {
    final ok = _requiredOk();
    if (!mounted) return;
    if (_canPublish == ok && !(_publishLocked && ok)) return;
    setState(() {
      _canPublish = ok;
      if (_publishLocked && ok) _publishLocked = false; // délock auto
    });
  }

  Future<bool> _ensureLoggedInForPublish() async {
    final user = await _resolveSignedInUser();
    if (user != null) return true;
    if (!mounted) return false;
    final overlayTheme = context.prestoOverlayTheme;

    final startInSignup = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                'Connecte-toi pour publier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ton formulaire reste rempli. Connecte-toi ou crée ton compte pour finaliser la publication.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrestoOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Je me connecte'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Je crée mon compte"),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Plus tard'),
              ),
            ],
          ),
        );
      },
    );

    if (startInSignup == null) return false;

    if (!mounted) return false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AccountPage(startInSignup: startInSignup),
      ),
    );

    if (!mounted) return false;

    return (await _resolveSignedInUser()) != null;
  }

  Future<User?> _resolveSignedInUser() async {
    final auth = _authOrNull;
    if (auth == null) return null;
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      SessionState.userId = currentUser.uid;
      return currentUser;
    }
    // Auth state is fully settled by the time the user interacts with a button.
    // Waiting on authStateChanges() here would block for up to 5 s when the
    // user is simply not signed in, delaying the auth popup unnecessarily.
    return null;
  }

  Future<User?> _ensureProtectedSessionReady({
    bool forceRefreshToken = false,
  }) async {
    final user = await _resolveSignedInUser();
    if (user == null) return null;

    try {
      await user.getIdToken(forceRefreshToken);
    } catch (e) {
      debugPrint('[PublishOffer] getIdToken failed: $e');
    }

    SessionState.userId = user.uid;
    return _authOrNull?.currentUser ?? user;
  }

  Future<void> _onPublishPressed() async {
    logRuntimeAction(
      area: 'publish',
      action: 'tap-submit',
      details: <String, Object?>{
        'signedIn': _authOrNull?.currentUser != null,
        'category': _category ?? '',
      },
    );

    _canonicalizeLocationInputs();

    setState(() {
      _attemptedSubmit = true;
      _publishLocked = true;
    });

    // Si l'utilisateur est déjà connecté, on peut préremplir les données profil
    // avant validation. Sinon on affiche d'abord les erreurs du formulaire.
    if (_authOrNull?.currentUser != null) {
      await _prefillPublishFromProfile();
      if (!mounted) return;
      _canonicalizeLocationInputs();
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || !_requiredOk()) {
      logRuntimeAction(
        area: 'publish',
        action: 'blocked-validation',
        details: <String, Object?>{'category': _category ?? ''},
      );
      setState(() => _showDarkOverlay = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstInvalidPublishField();
      });
      return;
    }

    final loggedIn = await _ensureLoggedInForPublish();
    if (!loggedIn) {
      logRuntimeAction(area: 'publish', action: 'blocked-auth');
      return;
    }

    await _prefillPublishFromProfile();
    if (!mounted) return;
    _canonicalizeLocationInputs();

    await _submitForm();
  }

  Future<void> _startMic() async {
    if (_isListening) return;
    _setPublishAiFlowStep(
      PublishOfferAiFlowStep.voiceSelected,
      reason: 'voice-start-requested',
    );
    final loggedIn = await _ensureLoggedInForPublish();
    if (!loggedIn) {
      _appendPublishAiTrace(
        'auth',
        'Connexion requise avant démarrage micro',
        level: PublishAiTraceLevel.warning,
      );
      return;
    }
    // Profile completeness gate: the AI button only opens after the user
    // has filled their display name + city + postal code. This avoids
    // generating drafts that cannot pass Firestore rules at publish time
    // (and gives a clear signal to incomplete accounts).
    final readiness = await _publishAiProfileReadiness.check();
    if (!readiness.isReady) {
      _appendPublishAiTrace(
        'profile_check',
        'Profil non complet — accès IA bloqué (${readiness.missingFields.join(", ")})',
        level: PublishAiTraceLevel.warning,
      );
      if (!mounted) return;
      showErrorSnackBar(context, readiness.describe());
      return;
    }
    if (_adminAudioRuntimeAccessState == 0) {
      unawaited(_refreshAdminAudioRuntimeAccess());
    }
    _resetPublishAiTrace(
      kIsWeb ? 'micro web classique' : 'micro mobile classique',
    );
    _appendPublishAiTrace(
      'start_mic',
      'Demande de démarrage du micro classique',
    );

    final appCheckReady = await _ensureAppCheckReady(
      flow: kIsWeb ? 'webMic' : 'mobileMic',
    );
    if (!appCheckReady) return;

    // ✅ Micro global: on ne fait PLUS speech_to_text (trop variable)
    // On enregistre l'audio puis _stopMic() déclenche le pipeline IA unifié.
    if (kIsWeb) {
      try {
        final secureContext = await _requirePublishAiSecureContext(
          stage: 'webMic.start',
          forceRefreshToken: true,
        );
        if (secureContext == null) return;
        final uid = secureContext.uid;

        await CrashlyticsContext.setUserId(uid);
        await CrashlyticsContext.setKey('flow', 'webMic');

        await _webRec.start();
        _rememberAdminAudioRuntime(
          flowKey: 'classic_web',
          label: 'Micro classique web',
          detail: _classicAdminAudioRuntimeDetail(),
        );
        if (!mounted) return;
        setState(() => _isListening = true);
        _setPublishAiFlowStep(
          PublishOfferAiFlowStep.voiceSelected,
          reason: 'voice-recording-started-web',
        );
        _appendPublishAiTrace(
          'start_mic',
          'Micro web démarré',
          level: PublishAiTraceLevel.success,
        );
      } catch (e, st) {
        await CrashlyticsContext.recordError(
          e is Exception ? e : Exception(e.toString()),
          st,
          reason: 'Web mic start failed',
          fatal: false,
          keys: {'component': 'Main', 'flow': 'webMic', 'step': 'start'},
        );
        if (!mounted) return;
        _appendPublishAiTrace(
          'start_mic',
          formatMicroIaRuntimeError(e),
          level: PublishAiTraceLevel.error,
        );
        showErrorSnackBar(
          context,
          'Micro web indisponible: ${formatMicroIaRuntimeError(e)}',
        );
      }
      return;
    }

    // Préparer l'enregistreur haute qualité (WAV)
    try {
      _recordingPath = null;
      final secureContext = await _requirePublishAiSecureContext(
        stage: 'mobileMic.start',
        forceRefreshToken: true,
      );
      if (secureContext == null) return;

      if (await _recorder.hasPermission()) {
        final filePath = await createTempAudioPath(
          prefix: 'presto',
          extension: 'm4a',
        );
        await _recorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: filePath,
        );
        _recordingPath = filePath;
      } else {
        _appendPublishAiTrace(
          'permission_micro',
          'Permission micro refusée',
          level: PublishAiTraceLevel.error,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Microphone non autorisé'),
            content: const Text(
              'Pour utiliser la dictée IA, autorise l\'accès au microphone dans les paramètres de ton téléphone :\nParamètres → Applications → Presto → Microphone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Recorder start error: $e');
      _recordingPath = null;
      _appendPublishAiTrace(
        'start_mic',
        formatMicroIaRuntimeError(e),
        level: PublishAiTraceLevel.error,
      );
      if (mounted) {
        showErrorSnackBar(
          context,
          'Micro indisponible: ${formatMicroIaRuntimeError(e)}',
        );
      }
      return;
    }

    setState(() {
      _rememberAdminAudioRuntime(
        flowKey: 'classic_mobile',
        label: 'Micro classique mobile',
        detail: _classicAdminAudioRuntimeDetail(),
      );
      _isListening = true;
    });
    _setPublishAiFlowStep(
      PublishOfferAiFlowStep.voiceSelected,
      reason: 'voice-recording-started-mobile',
    );
    _appendPublishAiTrace(
      'start_mic',
      kIsWeb ? 'Micro en écoute' : 'Enregistrement mobile lancé en AAC/m4a',
      level: PublishAiTraceLevel.success,
    );
  }

  Future<void> _stopMic() async {
    if (!_isListening) return;
    if (_isAnalyzing) return;
    _appendPublishAiTrace('stop_mic', 'Arrêt demandé pour le micro classique');

    final appCheckReady = await _ensureAppCheckReady(
      flow: kIsWeb ? 'webMic.stop' : 'mobileMic.stop',
    );
    if (!appCheckReady) {
      if (kIsWeb) {
        unawaited(() async {
          try {
            await _webRec.stopToBlob();
          } catch (_) {}
        }());
      } else {
        _recordingPath = null;
        unawaited(() async {
          try {
            await _recorder.stop();
          } catch (_) {}
        }());
      }
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _isAnalyzing = true;
      });
      _setPublishAiFlowStep(
        PublishOfferAiFlowStep.voiceAnalyzing,
        reason: 'voice-analysis-started-web',
      );

      try {
        // Pas de refresh forcé ici : le token a déjà été rafraîchi au
        // démarrage du micro (_startMic) — on réutilise la session chaude
        // pour ne pas payer un aller-retour réseau au moment du stop.
        final secureContext = await _requirePublishAiSecureContext(
          stage: 'webMic.stop',
          forceRefreshToken: false,
          showUserMessage: false,
        );
        final uid = secureContext?.uid;
        if (uid == null) {
          throw const MicroIaClientAuthException(
            code: 'auth-missing',
            message: 'Connecte-toi pour utiliser la dictée IA.',
          );
        }

        final blob = await _webRec.stopToBlob();
        // preferRawBytes: opus/webm brut envoyé tel quel (~10× plus léger que
        // le WAV) — la conversion WAV 16k se fait côté serveur via ffmpeg,
        // bien plus vite que decode+resample sur le thread UI.
        final audioUpload = await webBlobToMicroIaUpload(
          blob,
          preferRawBytes: true,
        );
        _appendPublishAiTrace(
          'web_audio',
          'Blob converti: ${audioUpload.bytes.length} bytes, ${audioUpload.contentType}, .${audioUpload.extension}',
        );
        if (audioUpload.bytes.isEmpty) {
          throw Exception('Audio invalide (fichier vide).');
        }
        if (audioUpload.usedClientSideWavConversion &&
            audioUpload.bytes.length < 30000) {
          throw Exception(
            'Audio invalide (WAV trop petit: ${audioUpload.bytes.length} bytes).',
          );
        }

        final audioResult = await _transcribePublishAudio(
          ownerUid: uid,
          audioBytes: audioUpload.bytes,
          contentType: audioUpload.contentType,
          extension: audioUpload.extension,
        );

        if (!mounted) return;

        await _applyPublishDraftFromTranscript(
          audioResult['text'] as String,
          combinedDraft: audioResult['draft'] as Map<String, dynamic>?,
        );
        _markPublishAiFlowCompleted('voice-analysis-success-web');

        if (mounted && _isAnalyzing) {
          setState(() => _isAnalyzing = false);
        }
        // _stopPublishAiVisualAfterDraftApply
      } catch (e, st) {
        await CrashlyticsContext.recordError(
          e is Exception ? e : Exception(e.toString()),
          st,
          reason: 'Web mic stop/process failed',
          fatal: false,
          keys: {'component': 'Main', 'flow': 'webMic', 'step': 'stop'},
        );
        if (!mounted) return;
        _appendPublishAiTrace(
          'stop_mic',
          formatMicroIaRuntimeError(e),
          level: PublishAiTraceLevel.error,
        );
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showErrorSnackBar(context, formatMicroIaRuntimeError(e));
        }
        _restorePublishAiFlowAfterError(fromVoice: true);
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
      return;
    }

    String? recordedPath;
    try {
      recordedPath = await _recorder.stop();
      recordedPath ??= _recordingPath;
      _recordingPath = null;
      _appendPublishAiTrace(
        'mobile_audio',
        recordedPath == null
            ? 'Aucun fichier audio retourné par le recorder'
            : 'Fichier enregistré: $recordedPath',
        level: recordedPath == null
            ? PublishAiTraceLevel.warning
            : PublishAiTraceLevel.success,
      );
    } catch (e) {
      debugPrint('Recorder stop error: $e');
      _recordingPath = null;
      _appendPublishAiTrace(
        'mobile_audio',
        formatMicroIaRuntimeError(e),
        level: PublishAiTraceLevel.error,
      );
    }
    setState(() {
      _isListening = false;
    });
    // Si l'audio est disponible et cloud STT activé, on passe par la fonction distante
    if (_useCloudStt && recordedPath != null) {
      setState(() => _isAnalyzing = true);
      _setPublishAiFlowStep(
        PublishOfferAiFlowStep.voiceAnalyzing,
        reason: 'voice-analysis-started-mobile',
      );
      try {
        await _uploadAndTranscribe(recordedPath);
        _markPublishAiFlowCompleted('voice-analysis-success-mobile');
      } catch (e) {
        _appendPublishAiTrace(
          'stop_mic',
          formatMicroIaRuntimeError(e),
          level: PublishAiTraceLevel.error,
        );
        if (!mounted) return;
        if (isTimeoutError(e)) {
          showTimeoutSnackBar(context);
        } else {
          showErrorSnackBar(context, formatMicroIaRuntimeError(e));
        }
        _restorePublishAiFlowAfterError(fromVoice: true);
      } finally {
        if (mounted) setState(() => _isAnalyzing = false);
      }
      return;
    }

    if (!mounted) return;
    _appendPublishAiTrace(
      'stop_mic',
      'Arrêt sans audio exploitable',
      level: PublishAiTraceLevel.warning,
    );
    showSuccessSnackBar(context, 'Aucun audio disponible');
  }

  Future<void> _uploadAndTranscribe(String localPath) async {
    // Upload vers Firebase Storage puis appel de la Cloud Function.
    // Le traitement reste côté backend pour conserver les secrets serveur.
    // Token déjà rafraîchi au démarrage du micro : pas de refresh forcé au
    // stop, la session chaude suffit (gain ~0,5-1 s sur le remplissage IA).
    final secureContext = await _requirePublishAiSecureContext(
      stage: 'uploadAndTranscribe',
      forceRefreshToken: false,
      showUserMessage: false,
    );
    final uid = secureContext?.uid;
    if (uid == null) {
      _appendPublishAiTrace(
        'auth',
        'Utilisateur non connecté au moment de l\'upload',
        level: PublishAiTraceLevel.error,
      );
      throw 'Utilisateur non connecté';
    }
    final xfile = XFile(localPath);
    final audioBytes = await xfile.readAsBytes();
    if (audioBytes.isEmpty) {
      _appendPublishAiTrace(
        'mobile_audio',
        'Fichier audio introuvable ou vide: $localPath',
        level: PublishAiTraceLevel.error,
      );
      throw 'Fichier audio introuvable';
    }
    final lower = localPath.toLowerCase();
    final isM4a = lower.endsWith('.m4a');
    final isMp4 = lower.endsWith('.mp4');
    final ext = isM4a ? 'm4a' : (isMp4 ? 'mp4' : 'wav');
    final contentType = (isM4a || isMp4) ? 'audio/mp4' : 'audio/wav';
    _appendPublishAiTrace(
      'mobile_audio',
      'Lecture locale OK: ${audioBytes.length} bytes, $contentType, .$ext',
      level: PublishAiTraceLevel.success,
    );
    final audioResult = await _transcribePublishAudio(
      ownerUid: uid,
      audioBytes: audioBytes,
      contentType: contentType,
      extension: ext,
    );

    if (!mounted) return;

    await _applyPublishDraftFromTranscript(
      audioResult['text'] as String,
      combinedDraft: audioResult['draft'] as Map<String, dynamic>?,
    );
  }

  /// Appelle la Cloud Function pour analyser la description avec OpenAI
  Future<void> _onTapAiAnalyze() async {
    _setPublishAiFlowStep(
      PublishOfferAiFlowStep.textSelected,
      reason: 'text-analysis-requested',
    );
    final input = _descriptionController.text.trim();
    if (input.isEmpty) {
      showSuccessSnackBar(context, "Veuillez d'abord saisir une description");
      return;
    }

    final loggedIn = await _ensureLoggedInForPublish();
    if (!loggedIn) {
      _appendPublishAiTrace(
        'auth',
        'Connexion requise avant analyse IA textuelle',
        level: PublishAiTraceLevel.warning,
      );
      return;
    }

    final readiness = await _publishAiProfileReadiness.check();
    if (!readiness.isReady) {
      _appendPublishAiTrace(
        'profile_check',
        'Profil non complet — accès IA bloqué (${readiness.missingFields.join(", ")})',
        level: PublishAiTraceLevel.warning,
      );
      if (!mounted) return;
      showErrorSnackBar(context, readiness.describe());
      return;
    }

    final appCheckReady = await _ensureAppCheckReady(flow: 'publishAiAnalyze');
    if (!appCheckReady) return;

    setState(() => _isAnalyzing = true);
    _setPublishAiFlowStep(
      PublishOfferAiFlowStep.textAnalyzing,
      reason: 'text-analysis-started',
    );

    try {
      _appendPublishAiTrace(
        'draft_remote',
        'Appel generateOfferDraftV2 depuis le bouton IA (format riche)',
      );
      final draft = await _aiService.generateOfferDraftV2(
        text: input,
        city: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        category: _category,
      );

      if (!mounted) return;

      if (draft['success'] == true) {
        // Snapshot the controllers before applying so we can detect whether
        // anything actually changed — otherwise the user-edit guards may have
        // silently skipped every field, leaving them with no visible result.
        final beforeSnapshot = <String, String>{
          'title': _titleController.text,
          'description': _descriptionController.text,
          'location': _locationController.text,
          'postal': _postalCodeController.text,
          'budget': _budgetController.text,
        };
        final beforeCategory = _category;

        // Always allow the AI to rewrite the description in the writing-assistant
        // flow (the user explicitly asked for their text to be reformulated).
        setState(() => _descriptionEditedByUser = false);
        _applyDraftToForm(draft);
        _applyKeywordCategoryPairFromText(input);
        _markLocationPostalPrefilledByAiIfChanged(beforeSnapshot);

        final didChange =
            beforeSnapshot['title'] != _titleController.text ||
            beforeSnapshot['description'] != _descriptionController.text ||
            beforeSnapshot['location'] != _locationController.text ||
            beforeSnapshot['postal'] != _postalCodeController.text ||
            beforeSnapshot['budget'] != _budgetController.text ||
            beforeCategory != _category;

        showSuccessSnackBar(
          context,
          didChange
              ? '✨ Analyse IA complétée\nChamps remplis automatiquement'
              : '✨ Analyse IA complétée — aucun nouveau champ à remplir',
        );
        _markPublishAiFlowCompleted('text-analysis-success');
        return;
      }

      final code = (draft['code'] ?? '').toString();
      _restorePublishAiFlowAfterError(fromVoice: false);
      showSuccessSnackBar(
        context,
        code == 'deadline-exceeded'
            ? 'Connexion lente, réessaie.'
            : 'Erreur IA: ${(draft['error'] ?? 'inconnue').toString()}',
      );
    } catch (e) {
      if (!mounted) return;
      _restorePublishAiFlowAfterError(fromVoice: false);
      showSuccessSnackBar(
        context,
        "Erreur lors de l'analyse : ${formatMicroIaRuntimeError(e)}",
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusManagerChange);
    _publishAiTraceDisposed = true;
    _publishAiTraceVersion.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    _locationController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    _budgetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetAllFields() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _postalCodeController.clear();
      _phoneController.clear();
      _budgetController.clear();
      _category = null;
      _selectedSubCategory = null;
      _missionDelay = null;
      _budgetType = 'Fixe';
      _selectedPhotos.clear();
      _selectedPhotoBytes.clear();
      _latestRecognizedTranscript = '';
      _titleEditedByUser = false;
      _descriptionEditedByUser = false;
      _locationEditedByUser = false;
      _postalCodeEditedByUser = false;
      _locationPostalPrefilledByAi = false;
      _isClearingAiPrefilledLocationPostal = false;
      _categoryEditedByUser = false;
      _delayEditedByUser = false;
      _budgetEditedByUser = false;
      _isApplyingProgrammaticPublishUpdate = false;
      _publishAiTraceEntries.clear();
      _citySuggestions.clear();
      _selectedPhoneCountryCode = '+33';
      _hidePhone = false;

      _isUrgent = false;

      _attemptedSubmit = false;
      _publishLocked = false;
      _canPublish = false;
      _publishAiFlowStep = PublishOfferAiFlowStep.chooseMethod;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
    unawaited(_prefillPublishFromProfile());
    showSuccessSnackBar(context, 'Tous les champs ont été réinitialisés');
  }

  // --- LOGIQUE AUTOCOMPLÉTION VILLE ---

  void _markLocationPostalPrefilledByAiIfChanged(
    Map<String, String> beforeSnapshot,
  ) {
    final locationChanged =
        beforeSnapshot['location'] != _locationController.text;
    final postalChanged =
        beforeSnapshot['postal'] != _postalCodeController.text;

    if (!locationChanged && !postalChanged) {
      return;
    }

    final hasLocationValue =
        _locationController.text.trim().isNotEmpty ||
        _postalCodeController.text.trim().isNotEmpty;

    if (hasLocationValue) {
      _locationPostalPrefilledByAi = true;
    }
  }

  void _clearAiPrefilledLocationPostalOnUserTap() {
    if (!_locationPostalPrefilledByAi ||
        _isClearingAiPrefilledLocationPostal ||
        _isApplyingProgrammaticPublishUpdate) {
      return;
    }

    final hasValue =
        _locationController.text.trim().isNotEmpty ||
        _postalCodeController.text.trim().isNotEmpty;

    if (!hasValue) {
      _locationPostalPrefilledByAi = false;
      return;
    }

    _isClearingAiPrefilledLocationPostal = true;
    setState(() {
      _locationController.clear();
      _postalCodeController.clear();
      _locationEditedByUser = false;
      _postalCodeEditedByUser = false;
      _citySuggestions = [];
      _locationPostalPrefilledByAi = false;
    });
    _isClearingAiPrefilledLocationPostal = false;
    _recompute();
  }

  void _onCityChanged(String value) {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _citySuggestions = [];
      });
      return;
    }

    final results = FrenchCityPostalValidator.instance.searchSuggestions(
      query,
      postalCodeHint: _postalCodeController.text,
      limit: 10,
    );
    final exactMatch = FrenchCityPostalValidator.instance.resolveExactTypedCity(
      city: query,
      postalCode: _postalCodeController.text,
    );
    setState(() {
      _citySuggestions = results;
    });

    if (exactMatch != null) {
      _applyCity(exactMatch, forceApply: true);
    }
  }

  void _onPostalCodeChanged(String value) {
    final cp = value.trim();
    if (cp.length < 2) {
      // On ne spam pas si l'utilisateur tape juste "7"
      return;
    }

    final results = FrenchCityPostalValidator.instance.searchSuggestions(
      '',
      postalCodeHint: cp,
      limit: 10,
    );

    if (!mounted) return;

    if (results.isEmpty) {
      setState(() {
        _citySuggestions = [];
      });
      return;
    }

    final best = FrenchCityPostalValidator.instance.resolveCanonicalCity(
      city: _locationController.text,
      postalCode: cp,
    );

    setState(() {
      _citySuggestions = results;
    });

    if (best != null) {
      _applyCity(best, forceApply: true);
    }
  }

  void _applyCity(
    CityRecord city, {
    bool markAsUserEdited = false,
    bool forceApply = false,
  }) {
    setState(() {
      if (forceApply || markAsUserEdited || !_locationEditedByUser) {
        _setControllerText(_locationController, city.name);
      }
      if (forceApply || markAsUserEdited || !_postalCodeEditedByUser) {
        _setControllerText(_postalCodeController, city.cp);
      }

      _selectedPhoneCountryCode = countryCodeForDept(city.dept);
      if (markAsUserEdited) {
        _locationEditedByUser = true;
        _postalCodeEditedByUser = true;
      }

      _citySuggestions = [];
    });
  }

  String countryCodeForDept(String dept) {
    if (dept.startsWith('971')) return '+590'; // Guadeloupe
    if (dept.startsWith('972')) return '+596'; // Martinique
    if (dept.startsWith('973')) return '+594'; // Guyane
    if (dept.startsWith('974')) return '+262'; // La Réunion
    if (dept.startsWith('976')) return '+262'; // Mayotte
    if (dept.startsWith('987')) return '+689'; // Polynésie
    return '+33'; // Métropole par défaut
  }

  // --- GESTION DES PHOTOS ---

  Future<void> _showPhotoPopup({
    required XFile file,
    required String label,
  }) async {
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final overlayTheme = context.prestoOverlayTheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: overlayTheme.surfaceColor,
          surfaceTintColor: overlayTheme.surfaceTintColor,
          shape: overlayTheme.dialogShape,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: overlayTheme.dialogRadius,
                child: Container(
                  color: overlayTheme.surfaceColor,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'Image indisponible',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onPhotoTileTap(int photoIndex) async {
    if (photoIndex < _selectedPhotos.length) {
      final file = _selectedPhotos[photoIndex];
      final label = 'Photo ${photoIndex + 1}';
      await _showPhotoPopup(file: file, label: label);
      return;
    }
    await _pickImage(photoIndex);
  }

  Future<ImageSource?> _selectPhotoSource() async {
    if (!mounted) return null;
    final overlayTheme = context.prestoOverlayTheme;

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(kIsWeb ? 'Fichiers / galerie' : 'Galerie'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
                ListTile(
                  enabled: !kIsWeb,
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Appareil photo'),
                  subtitle: kIsWeb
                      ? const Text('Disponible sur mobile uniquement')
                      : null,
                  onTap: kIsWeb
                      ? null
                      : () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(int photoIndex) async {
    if (_selectedPhotos.length >= _maxListingPhotos &&
        photoIndex >= _selectedPhotos.length) {
      final photoLabel = _maxListingPhotos > 1 ? 'photos' : 'photo';
      showSuccessSnackBar(
        context,
        'Maximum $_maxListingPhotos $photoLabel autorisées',
      );
      return;
    }

    try {
      final source = await _selectPhotoSource();
      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image == null) return;

      final bytes = await image.readAsBytes();

      setState(() {
        if (photoIndex < _selectedPhotos.length) {
          _selectedPhotos[photoIndex] = image;
          if (photoIndex < _selectedPhotoBytes.length) {
            _selectedPhotoBytes[photoIndex] = bytes;
          } else {
            while (_selectedPhotoBytes.length < photoIndex) {
              _selectedPhotoBytes.add(null);
            }
            _selectedPhotoBytes.add(bytes);
          }
        } else {
          _selectedPhotos.add(image);
          while (_selectedPhotoBytes.length < _selectedPhotos.length - 1) {
            _selectedPhotoBytes.add(null);
          }
          _selectedPhotoBytes.add(bytes);
        }
      });

      // Détection métier → catégorie/sous-catégorie en arrière-plan (~400-600 ms).
      // Déclenché uniquement si la catégorie n'a pas encore été choisie.
      if (!_categoryEditedByUser && (_category ?? '').trim().isEmpty) {
        unawaited(_classifyPhotoAndApply(bytes));
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur lors de la sélection : $e');
    }
  }

  /// Classifie la photo via GPT-4o-mini (enum fermé) et pré-remplit
  /// catégorie + sous-catégorie si la confiance est suffisante.
  Future<void> _classifyPhotoAndApply(Uint8List bytes) async {
    if (!mounted) return;
    setState(() => _isClassifyingPhoto = true);
    try {
      final b64 = base64Encode(bytes);
      final result = await _tradeClassifier.classifyFromBase64(b64);

      if (!mounted || _categoryEditedByUser) return;
      if (!result.isConfident || result.match == null) return;

      final match = result.match!;
      final resolvedCategory = resolvePublishCategoryLabel(match.categorie);
      if (resolvedCategory == null) return;

      final availableSubs =
          kCategorySubcategories[resolvedCategory] ?? const <String>[];

      setState(() {
        if ((_category ?? '').trim().isEmpty) {
          _category = resolvedCategory;
          _selectedSubCategory = null;
        }
        if ((_selectedSubCategory ?? '').trim().isEmpty &&
            availableSubs.contains(match.sousCat)) {
          _selectedSubCategory = match.sousCat;
        }
      });

      if (mounted) {
        showPrestoSnackBar(context, 'Catégorie détectée : $resolvedCategory');
      }
    } on FirebaseFunctionsException catch (e) {
      // Erreur réseau ou AppCheck — silencieux (non critique)
      debugPrint('classifyPhoto: ${e.code}');
    } catch (e) {
      debugPrint('classifyPhoto: $e');
    } finally {
      if (mounted) setState(() => _isClassifyingPhoto = false);
    }
  }

  void _removePhotoAt(int photoIndex) {
    if (photoIndex < 0 || photoIndex >= _selectedPhotos.length) {
      return;
    }

    setState(() {
      _selectedPhotos.removeAt(photoIndex);
      if (photoIndex < _selectedPhotoBytes.length) {
        _selectedPhotoBytes.removeAt(photoIndex);
      }
    });
  }

  String storageExtFromPhoto(XFile photo) {
    final mime = (photo.mimeType ?? '').toLowerCase().trim();
    if (mime == 'image/webp') return 'webp';
    if (mime == 'image/png') return 'png';
    if (mime == 'image/heic' || mime == 'image/heif') return 'heic';
    if (mime == 'image/gif') return 'gif';

    final path = photo.path.toLowerCase();
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.heic') || path.endsWith('.heif')) return 'heic';
    if (path.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  String storageContentTypeFromPhoto(XFile photo) {
    final mime = (photo.mimeType ?? '').toLowerCase().trim();
    if (mime.startsWith('image/')) return mime;

    final ext = storageExtFromPhoto(photo);
    switch (ext) {
      case 'webp':
        return 'image/webp';
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  /// Crée des notifications pour les utilisateurs ayant cette catégorie en favori
  Future<void> _createNotificationsForFavorites(
    String offerId,
    String category,
    String? subCategory,
    String offerTitle,
    String publisherUserId,
  ) async {
    // 🔒 Sécurité: la création de notifications se fait côté serveur (Cloud Functions)
    // afin d'éviter qu'un client puisse créer des notifications pour d'autres utilisateurs.
    return;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    // Préflight auth / App Check / profil — bloquant car nécessaire avant de
    // pouvoir publier. En cas d'échec on s'arrête sans afficher le popup.
    User? maybeUser;
    try {
      maybeUser = await _ensureProtectedSessionReady(forceRefreshToken: true);
    } catch (e) {
      logRuntimeAction(
        area: 'publish',
        action: 'submit-failure',
        details: <String, Object?>{
          'errorType': e.runtimeType,
          'message': e,
          'phase': 'preflight',
        },
      );
      if (mounted) {
        showErrorSnackBar(
          context,
          'Erreur lors de la publication : ${formatPublishError(e)}',
        );
        setState(() => _isSubmitting = false);
      }
      return;
    }
    if (maybeUser == null) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Erreur lors de la publication : utilisateur non connecté.',
        );
        setState(() => _isSubmitting = false);
      }
      return;
    }
    final user = maybeUser;

    try {
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: false,
      );
    } catch (error, stackTrace) {
      await CrashlyticsContext.recordError(
        error,
        stackTrace,
        reason:
            'publish blocked before submit: auth/appcheck/profile preflight failed',
        fatal: false,
        keys: <String, String>{
          'component': 'PublishOfferPage',
          'step': 'submit-preflight',
          'uid': user.uid,
        },
      );
      if (UserProfileBootstrapService.isAppCheckFailure(error)) {
        debugPrint(
          '[PublishOffer] App Check preflight failed; continuing to protected draft write retry: $error',
        );
      } else {
        if (mounted) {
          showErrorSnackBar(
            context,
            "Synchronisation de ton profil impossible. Recharge l'application puis réessaie. Si le blocage continue, vérifie App Check et tes droits utilisateur.",
          );
          setState(() => _isSubmitting = false);
        }
        return;
      }
    }

    logRuntimeAction(
      area: 'publish',
      action: 'submit-start',
      details: <String, Object?>{
        'userId': user.uid,
        'category': _category ?? '',
        'city': _locationController.text.trim(),
        'hasPhotos': _selectedPhotos.isNotEmpty,
      },
    );

    final budgetValue = _budgetType == 'À négocier'
        ? 0.0
        : (parseBudget(_budgetController.text) ?? 0.0);
    final publishService = _marketplacePublishService ??=
        MarketplacePublishService();

    // UX « instantané » : on lance l'envoi (upload photos + création annonce)
    // en arrière-plan, puis on affiche immédiatement le popup « en attente de
    // validation » et on route vers « Je consulte » (onglet 1). Le suivi
    // (analytics, notifications, erreurs) est traité quand le Future se résout.
    final publishFuture = publishService.publish(
      ownerId: user.uid,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category:
          resolvePublishCategoryLabel(_category) ?? (_category ?? '').trim(),
      city: _locationController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      phone:
          '${_selectedPhoneCountryCode.trim()} ${_phoneController.text.trim()}'
              .trim(),
      subCategory: _selectedSubCategory,
      missionDelay: _missionDelay,
      isUrgent: _isUrgent,
      price: budgetValue,
      budgetType: _budgetType,
      hidePhone: _hidePhone,
      photos: List<XFile>.from(_selectedPhotos),
    );

    unawaited(
      _finalizePublishInBackground(
        publishFuture,
        ownerId: user.uid,
        title: _titleController.text.trim(),
        category: (_category ?? '').toString().trim(),
        subCategory: _selectedSubCategory,
        budget: _budgetController.text.trim(),
        budgetType: _budgetType,
      ),
    );

    if (!mounted) return;
    await showModerationPendingDialog(context);
    appNavigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage(initialIndex: 1)),
    );
  }

  /// Termine la publication lancée en arrière-plan (flux UX instantané).
  /// Succès : analytics + notifications. Échec : log + report d'erreur via le
  /// navigateur global, car la page de publication a déjà été quittée.
  Future<void> _finalizePublishInBackground(
    Future<MarketplacePublishResult> publishFuture, {
    required String ownerId,
    required String title,
    required String category,
    required String? subCategory,
    required String budget,
    required String budgetType,
  }) async {
    try {
      final publishResult = await publishFuture;

      // ✅ Analytics: publication
      await _logOfferPublished(
        offerId: publishResult.listingId,
        title: title,
        category: category,
        budget: budget,
        budgetType: budgetType,
      );

      // Notifications favoris (création côté serveur — no-op client)
      await _createNotificationsForFavorites(
        publishResult.listingId,
        category,
        subCategory,
        title,
        ownerId,
      );

      logRuntimeAction(
        area: 'publish',
        action: 'submit-success',
        details: <String, Object?>{
          'listingId': publishResult.listingId,
          'category': category,
        },
      );
    } catch (e) {
      logRuntimeAction(
        area: 'publish',
        action: 'submit-failure',
        details: <String, Object?>{
          'errorType': e.runtimeType,
          'message': e,
          'phase': 'background',
        },
      );
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null && ScaffoldMessenger.maybeOf(ctx) != null) {
        showErrorSnackBar(
          ctx,
          'Échec de la publication : ${formatPublishError(e)}',
        );
      }
    }
  }

  Widget _buildPublishAiAnalyzingBanner() {
    if (!_isAnalyzing) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF13C8FF), Color(0xFF0078FF), Color(0xFF004BE8)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x6613A8FF),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          children: [
            OrbitingAiVisual(size: 60),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analyse IA en cours...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Nous préparons automatiquement votre annonce.',
                    style: TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final publishVisuallyDisabled = !_canPublish || _isSubmitting;
    final isDescriptionActive = _isTextFlowActive;
    final shouldDimDescription =
        !_isPublishFlowCompleted && !isDescriptionActive;
    final shouldDimRemainingSections = !_isPublishFlowCompleted;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoOrange),
          backgroundColor: kPrestoOrange,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          title: const Text(
            'Je publie une offre',
            style: kPrestoAppBarTitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Réinitialiser tous les champs',
              onPressed: () {
                final overlayTheme = context.prestoOverlayTheme;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: overlayTheme.surfaceColor,
                    surfaceTintColor: overlayTheme.surfaceTintColor,
                    shape: overlayTheme.dialogShape,
                    title: const Text(
                      'Réinitialiser ?',
                      style: kPrestoSectionTitleStyle,
                    ),
                    content: const Text(
                      'Voulez-vous effacer tous les champs et recommencer ?',
                      style: kPrestoBodyTextStyle,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: kPrestoBlue,
                        ),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetAllFields();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrestoOrange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Form(
                key: _formKey,
                autovalidateMode: _attemptedSubmit
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(6, 16, 6, 150),
                  children: [
                    const SizedBox(height: 6),
                    ClipRRect(
                      // _publishAiMicroOrbitFocusStack
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          AiPublishControlWithCredits(
                            state: _aiPublishState,
                            micAnchorLink: _publishAiMicAnchorLink,
                            isAudioAnalyzing: _isAnalyzing,
                            onStartRecording: _startMic,
                            onStopRecording: _stopMic,
                            onSelectVocal: _onSelectVoiceMethod,
                            onSelectText: _onSelectTextMethod,
                            onDiagnostic: _showPublishAiTraceDialog,
                            onClear: _clearPublishAiTrace,
                            showAdminDiagnostics:
                                _adminAudioRuntimeAccessState == 1,
                            highlightVocalCard: _isVoiceFlowActive,
                            dimVocalCard:
                                !_isPublishFlowCompleted && !_isVoiceFlowActive,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_publishAiFlowStep ==
                            PublishOfferAiFlowStep.textSelected ||
                        _publishAiFlowStep ==
                            PublishOfferAiFlowStep.textAnalyzing ||
                        _publishAiFlowStep ==
                            PublishOfferAiFlowStep.completed) ...[
                      _buildPublishAiFlowHint(),
                      const SizedBox(height: 16),
                    ],

                    // DESCRIPTION
                    _guidedSection(
                      isActive: isDescriptionActive,
                      isDimmed: shouldDimDescription,
                      neonBorder: true,
                      child: _withPublishFieldHighlight(
                        fieldId: 'description',
                        child: _withAiPendingOverlay(
                          showPending: _showAiPendingForController(
                            _descriptionController,
                          ),
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(top: 14, right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _descriptionController,
                                focusNode: _descriptionFocusNode,
                                readOnly: _descriptionTapToEditPrimed,
                                showCursor: _descriptionTapToEditPrimed
                                    ? true
                                    : null,
                                textAlignVertical: TextAlignVertical.top,
                                onTap: _unlockDescriptionEditing,
                                decoration: InputDecoration(
                                  label: _requiredLabel(
                                    'Description détaillée',
                                  ),
                                  alignLabelWithHint: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    12,
                                    14,
                                    12,
                                    14,
                                  ),
                                  hintText:
                                      'Je cherche un (compétence)… pour effectuer (mission)… dans le secteur de (ville / région)… J\'offre (€).',
                                  hintStyle: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFFBBC0CF),
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                                minLines: 4,
                                maxLines: 8,
                                validator: validatePublishDescription,
                              ),
                              const SizedBox(height: 8),
                              AiWritingButton(
                                isAnalyzing: _isAnalyzing,
                                onTap: !_isAnalyzing && !_isListening
                                    ? _onTapAiAnalyze
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _guidedSection(
                      isActive: _isPublishFlowCompleted,
                      isDimmed: shouldDimRemainingSections,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // TITRE
                          _withPublishFieldHighlight(
                            fieldId: 'title',
                            child: _withAiPendingOverlay(
                              showPending: _showAiPendingForController(
                                _titleController,
                              ),
                              child: TextFormField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  label: _requiredLabel("Titre de l'offre"),
                                  border: const OutlineInputBorder(),
                                  hintText: 'Ex : Monter un meuble IKEA',
                                ),
                                validator: validatePublishTitle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          PublishOfferCategoryFields(
                            categoryLabel: _requiredLabel('Catégorie'),
                            categories: _categories,
                            subcategories: _category == null
                                ? const <String>[]
                                : (kCategorySubcategories[_category] ??
                                      const <String>[]),
                            selectedCategory: _category,
                            selectedSubcategory: _selectedSubCategory,
                            categoryDecorator: (child) =>
                                _withPublishFieldHighlight(
                                  fieldId: 'category',
                                  child: _withAiPendingOverlay(
                                    showPending: _showAiPendingForCategory,
                                    child: child,
                                  ),
                                ),
                            onCategoryChanged: (value) {
                              setState(() {
                                _categoryEditedByUser = true;
                                _category = value;
                                _selectedSubCategory = null;
                              });
                              _recompute();
                            },
                            onSubcategoryChanged: (value) {
                              setState(() {
                                _selectedSubCategory = value;
                              });
                              _recompute();
                            },
                          ),

                          // PHOTOS
                          PublishOfferPhotosSection(
                            visibleTileCount: _visiblePhotoTileCount,
                            maximumPhotos: _publishPhotoHardLimit,
                            selectedPhotos: _selectedPhotos,
                            selectedPhotoBytes: _selectedPhotoBytes,
                            onPhotoTap: _onPhotoTileTap,
                            onPhotoLongPress: _pickImage,
                            onPhotoRemove: _removePhotoAt,
                          ),
                          const SizedBox(height: 16),

                          PublishOfferLocationFields(
                            cityController: _locationController,
                            postalCodeController: _postalCodeController,
                            cityLabel: _requiredLabel('Ville'),
                            cityDecorator: (child) =>
                                _withPublishFieldHighlight(
                                  fieldId: 'city',
                                  child: _withAiPendingOverlay(
                                    showPending: _showAiPendingForController(
                                      _locationController,
                                    ),
                                    child: child,
                                  ),
                                ),
                            postalDecorator: (child) => _withAiPendingOverlay(
                              showPending: _showAiPendingForController(
                                _postalCodeController,
                              ),
                              child: child,
                            ),
                            onCitySelected: (city) {
                              setState(() {
                                _selectedPhoneCountryCode = countryCodeForDept(
                                  city.dept,
                                );
                                _locationEditedByUser = true;
                                _postalCodeEditedByUser = true;
                              });
                            },
                            onPostalTap:
                                _clearAiPrefilledLocationPostalOnUserTap,
                            onPostalEditingComplete:
                                _canonicalizeLocationInputs,
                            postalValidator: _validatePostalCode,
                          ),
                          PublishOfferPhoneFields(
                            controller: _phoneController,
                            label: _requiredLabel(
                              'Téléphone (pour être rappelé)',
                            ),
                            hintText: phoneHintForCountryCode(
                              _selectedPhoneCountryCode,
                            ),
                            initialCountryCode: _selectedPhoneCountryCode,
                            phoneDecorator: (child) =>
                                _withPublishFieldHighlight(
                                  fieldId: 'phone',
                                  child: child,
                                ),
                            onCountryCodeChanged: (code) {
                              setState(() {
                                _selectedPhoneCountryCode = code;
                              });
                            },
                            onPhoneChanged: (_) => _recompute(),
                            validator: (value) {
                              return isValidPhoneFR(value ?? '')
                                  ? null
                                  : 'Téléphone invalide';
                            },
                            hidePhone: _hidePhone,
                            onHidePhoneChanged: (value) {
                              setState(() => _hidePhone = value);
                            },
                          ),

                          PublishOfferMissionFields(
                            delayLabel: _requiredLabel(
                              'Délai pour effectuer la mission',
                            ),
                            delayOptions: _missionDelayOptions,
                            selectedDelay: _missionDelay,
                            delayDecorator: (child) =>
                                _withPublishFieldHighlight(
                                  fieldId: 'delay',
                                  child: child,
                                ),
                            onDelayChanged: (value) {
                              setState(() {
                                _delayEditedByUser = true;
                                _missionDelay = value;
                                _isUrgent = value == 'Urgent';
                              });
                              _recompute();
                            },
                            budgetTypes: _budgetTypes,
                            selectedBudgetType: _budgetType,
                            budgetController: _budgetController,
                            budgetLabel: _budgetType == 'À négocier'
                                ? const Text('Budget')
                                : _requiredLabel('Budget (€)'),
                            budgetDecorator: (child) =>
                                _withPublishFieldHighlight(
                                  fieldId: 'budget',
                                  child: child,
                                ),
                            onBudgetTypeChanged: (value) {
                              setState(() {
                                _budgetEditedByUser = true;
                                _budgetType = value;
                              });
                              _recompute();
                            },
                            budgetValidator: (value) {
                              if (_budgetType == 'À négocier') return null;
                              final budget = parseBudget(value ?? '');
                              if (budget == null) return 'Montant invalide';
                              if (budget <= 0) {
                                return 'Le montant doit être > 0';
                              }
                              return null;
                            },
                          ),

                          const Text(
                            '* Champs obligatoires',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          PublishValidationBanner(
                            missingFields: _attemptedSubmit
                                ? _missingPublishFieldLabels()
                                : const [],
                          ),
                          if (_attemptedSubmit &&
                              _missingPublishFieldLabels().isNotEmpty)
                            const SizedBox(height: 10),

                          // BOUTON PUBLIER
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : _onPublishPressed,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                _isSubmitting
                                    ? 'Publication en cours...'
                                    : 'Publier mon offre',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: publishVisuallyDisabled
                                    ? Colors.grey.shade400
                                    : kPrestoOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
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
              if (_showDarkOverlay)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _showDarkOverlay ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xBB000000)),
                      ),
                    ),
                  ),
                ),
              if (_publishAiFlowStep == PublishOfferAiFlowStep.voiceAnalyzing)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CompositedTransformFollower(
                      link: _publishAiMicAnchorLink,
                      showWhenUnlinked: false,
                      targetAnchor: Alignment.center,
                      followerAnchor: Alignment.center,
                      child: const _PublishAiMicroOrbitFocus(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishAiMicroOrbitFocus extends StatelessWidget {
  const _PublishAiMicroOrbitFocus();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A73E8).withValues(alpha: 0.30),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const OrbitingAiVisual(
        size: 48,
        strokeColor: Color(0xCC1A73E8),
        dotColor: Color(0xFF4EA1FF),
      ),
    );
  }
}

Future<void> showModerationPendingDialog(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (_) => const _ModerationPendingDialog(),
  );

  await Future.delayed(const Duration(seconds: 2));
  if (navigator.canPop()) {
    navigator.pop();
  }
}

class _ModerationPendingDialog extends StatelessWidget {
  const _ModerationPendingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Opacity(opacity: scale.clamp(0, 1), child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A73E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Annonce en attente de validation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kPrestoBlue,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Votre annonce est en cours de vérification. Elle sera publiée si elle respecte les règles de modération.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPendingDots extends StatelessWidget {
  const _FieldPendingDots();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FieldPendingDot(delay: 0),
            SizedBox(width: 4),
            _FieldPendingDot(delay: 180),
            SizedBox(width: 4),
            _FieldPendingDot(delay: 360),
          ],
        ),
      ),
    );
  }
}

class _FieldPendingDot extends StatefulWidget {
  final int delay;

  const _FieldPendingDot({required this.delay});

  @override
  State<_FieldPendingDot> createState() => _FieldPendingDotState();
}

class _FieldPendingDotState extends State<_FieldPendingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _opacity = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: kPrestoBlue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
