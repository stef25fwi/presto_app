import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/presto_overlay_theme.dart';
import '../../constants.dart';
import '../../features/micro_ia/web_audio_recorder_stub.dart'
    if (dart.library.js_interop) '../../features/micro_ia/web_audio_recorder.dart';
import '../../features/subscriptions/subscription_action_placeholders.dart';
import '../../features/subscriptions/subscription_config_service.dart';
import '../../features/subscriptions/subscription_models.dart';
import '../../services/conversation_service.dart';
import '../../services/conversation_state.dart';
import '../../services/admin_access_resolver.dart';
import '../../services/admin_web_debug_store.dart';
import '../../services/conversation_participants.dart';
import '../../services/firestore_date_parser.dart';
import '../../services/user_profile_bootstrap_service.dart';
import '../../utils/friendly_snackbar.dart';
import '../../utils/local_audio_preview_source_io.dart'
    if (dart.library.js_interop) '../../utils/local_audio_preview_source_web.dart';
import '../../utils/open_attachment_file_web.dart'
    if (dart.library.io) '../../utils/open_attachment_file_io.dart';
import '../../widgets/offer_network_image.dart';
import 'package:presto_app/services/auth_guard.dart';
import 'package:presto_app/utils/profile_avatar_resolver.dart';
import '../../utils/recording_path_web.dart'
    if (dart.library.io) '../../utils/recording_path_io.dart';
import '../../utils/temp_file_helper_web.dart'
    if (dart.library.io) '../../utils/temp_file_helper_io.dart';
import 'package:presto_app/widgets/deleted_user_profile.dart';
import 'package:presto_app/pages/fiche_pro_page.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);
const kThreadMineColor = Color(0xFFD9FDD3);
const kThreadOtherColor = Colors.white;
const kThreadBackground = Color(0xFFFFFEFE);
const kWhatsappGreen = Color(0xFF25D366);
const kConversationThreadStatusBarStyle = SystemUiOverlayStyle(
  statusBarColor: kPrestoOrange,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

class ConversationThreadPage extends StatefulWidget {
  final String conversationId;
  final String offerTitle;
  final String currentUserId;
  final String? initialDraftText;

  const ConversationThreadPage({
    super.key,
    required this.conversationId,
    required this.offerTitle,
    required this.currentUserId,
    this.initialDraftText,
  });

  @override
  State<ConversationThreadPage> createState() => _ConversationThreadPageState();
}

class _ConversationThreadPageState extends State<ConversationThreadPage> {
  static const int _messagePageSize = 50;
  final AdminAccessResolver _adminAccessResolver = AdminAccessResolver();
  final SubscriptionConfigService _subscriptionConfigService =
      SubscriptionConfigService();
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<OptimisticMessage> _optimisticMessages = <OptimisticMessage>[];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _conversationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _presenceSubscription;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _olderMessageDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  Timer? _typingStopTimer;
  QueryDocumentSnapshot<Map<String, dynamic>>? _paginationAnchorDoc;
  Future<OfferPreview?>? _offerPreviewFuture;
  String? _offerPreviewFutureId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messageStream;
  bool _isSending = false;
  bool _hasDraftText = false;
  bool _isMarkingRead = false;
  bool _hasAttemptedOlderPagination = false;
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;
  List<String> threadParticipants = const [];
  Map<String, String> _participantNames = const {};
  Map<String, dynamic> threadLastReadAt = const {};
  bool _metaLoaded = false;
  bool didApplyInitialDraft = false;
  bool showSafetyReminder = true;
  bool _isOfferCardExpanded = true;
  bool _showEmojiStrip = false;
  static const List<String> _defaultQuickEmojis = [
    '👍',
    '🙏',
    '😊',
    '👌',
    '🔥',
    '💬',
  ];
  List<String> _quickEmojis = _defaultQuickEmojis;
  Map<String, int> _emojiUsageCounts = const {};
  bool _didLoadEmojiUsage = false;
  bool otherIsTyping = false;
  bool _showNewMessagesButton = false;
  bool _isUploadingAttachment = false;
  final Set<String> _deletingMessageIds = {};
  bool _canLookupOtherParticipantProfile = false;
  bool _isPreparingMessageStream = true;
  bool adminViewerState = false;
  String? _newestLiveMessageId;
  bool conversationBlocked = false;
  bool blockedForCurrentUser = false;
  bool blockedByAnotherParticipant = false;
  bool archivedForCurrentUser = false;
  bool _isDeletedForCurrentUser = false;
  bool _hasHandledConversationRemoval = false;
  int _messageStreamRetryCount = 0;
  String _offerId = '';
  String conversationOfferTitle = '';
  String _otherParticipantId = '';
  String otherParticipantNameState = '';
  String _otherParticipantPhotoSource = '';
  String _otherParticipantPhotoUrl = '';
  String otherPresenceStatus = '';
  DateTime? otherLastSeenAt;
  bool _isRecording = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  final WebAudioRecorder _webVoiceRecorder = WebAudioRecorder();
  AudioRecorder? _voiceRecorder;
  String? _currentRecordingPath;
  bool _isWebVoiceRecording = false;
  Future<bool> _ensureAttachmentAllowed({
    required String uid,
    required String attachmentType,
  }) async {
    try {
      final decision = await _resolveAttachmentGateDecision(
        uid: uid,
        attachmentType: attachmentType,
      );
      if (decision == null) return true;
      if (!mounted) return false;
      await _showAttachmentSubscriptionGate(decision);
      return false;
    } catch (error) {
      debugPrint('[ConversationThread] subscription gate skipped: $error');
      return true;
    }
  }

  Future<_ConversationAttachmentGateDecision?> _resolveAttachmentGateDecision({
    required String uid,
    required String attachmentType,
  }) async {
    final config = await _subscriptionConfigService.getConfig();
    if (config.freeAccessMode) {
      return null;
    }
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userState = AppUserSubscriptionState.fromMap(userSnapshot.data());
    final entitlements = getConversationAttachmentEntitlements(
      userState.plan,
      freeAccessMode: config.freeAccessMode,
    );
    if (attachmentType == 'document' && !entitlements.canSendDocuments) {
      return _ConversationAttachmentGateDecision(
        title: 'Fichiers réservés à ilipresto+',
        message:
            'Les documents et autres fichiers sont prévus pour ilipresto+. En gratuit, vous gardez les messages texte, 1 photo et 1 note audio par conversation.',
        source: 'messages_document_gate',
        stripeEnabled: config.stripeEnabled,
      );
    }
    if (attachmentType == 'image') {
      final sentPhotos = await _countSentAttachmentsOfType(
        uid: uid,
        attachmentType: 'image',
      );
      if (sentPhotos >= entitlements.maxPhotosPerConversation) {
        return _ConversationAttachmentGateDecision(
          title: 'Quota photo atteint',
          message:
              'L’offre gratuite est préparée pour 1 photo par conversation. Passez à ilipresto+ pour envoyer davantage de pièces jointes.',
          source: 'messages_photo_limit_gate',
          stripeEnabled: config.stripeEnabled,
        );
      }
    }
    if (attachmentType == 'audio') {
      final sentAudios = await _countSentAttachmentsOfType(
        uid: uid,
        attachmentType: 'audio',
      );
      if (sentAudios >= entitlements.maxAudioPerConversation) {
        return _ConversationAttachmentGateDecision(
          title: 'Quota audio atteint',
          message:
              'L’offre gratuite est préparée pour 1 note audio par conversation. Passez à ilipresto+ pour aller plus loin.',
          source: 'messages_audio_limit_gate',
          stripeEnabled: config.stripeEnabled,
        );
      }
    }
    return null;
  }

  Future<int> _countSentAttachmentsOfType({
    required String uid,
    required String attachmentType,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .where('senderId', isEqualTo: uid)
        .get();
    var count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['deletedAt'] != null || data['isDeleted'] == true) {
        continue;
      }
      final attachments = MessageAttachment.fromList(data['attachments']);
      count += attachments
          .where((attachment) => attachment.type == attachmentType)
          .length;
    }
    return count;
  }

  Future<void> _showAttachmentSubscriptionGate(
    _ConversationAttachmentGateDecision decision,
  ) async {
    final overlayTheme = context.prestoOverlayTheme;
    final wantsPlan = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  decision.title,
                  textAlign: TextAlign.center,
                  style: kPrestoSectionTitleStyle,
                ),
                const SizedBox(height: 10),
                Text(
                  decision.message,
                  textAlign: TextAlign.center,
                  style: kPrestoBodyTextStyle.copyWith(
                    color: const Color(0xFF4B5563),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Plus tard'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Découvrir ilipresto+'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrestoBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (wantsPlan != true || !mounted) return;
    if (decision.stripeEnabled) {
      await startSubscriptionCheckout(
        context,
        'ilipresto_plus',
        stripeEnabled: true,
        source: decision.source,
      );
      return;
    }
    await notifySubscriptionLaunch(
      context,
      'ilipresto_plus',
      stripeEnabled: false,
      source: decision.source,
    );
  }

  Object? conversationValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (value != null) return value;
    }
    return null;
  }

  void _debugMessagingAccess(
    String reason, {
    Object? error,
    List<String>? participants,
    String? firestorePath,
  }) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
    final detail =
        'currentUser.uid=$currentUid '
        'widget.currentUserId=${widget.currentUserId} '
        'conversationId=${widget.conversationId} '
        'path=${firestorePath ?? 'conversations/${widget.conversationId}'} '
        'participants=${participants ?? threadParticipants} '
        'error=$error';
    if (error != null) {
      AdminWebDebugStore.instance.recordError(
        'messages-thread',
        error,
        message: reason,
      );
      AdminWebDebugStore.instance.recordEvent(
        area: 'messages-thread',
        message: reason,
        level: 'error',
        detail: detail,
      );
    } else {
      AdminWebDebugStore.instance.recordEvent(
        area: 'messages-thread',
        message: reason,
        level:
            reason.contains('retry') ||
                reason.contains('missing') ||
                reason.contains('not-found')
            ? 'warn'
            : 'info',
        detail: detail,
      );
    }
    if (!kDebugMode) return;
    debugPrint('[ConversationThread][access] reason=$reason $detail');
  }

  String messagingErrorCode(Object? error) {
    if (error is FirebaseException) return error.code;
    if (error is FirebaseFunctionsException) return error.code;
    final text = (error ?? '').toString().toLowerCase();
    for (final code in const <String>[
      'permission-denied',
      'not-found',
      'unauthenticated',
      'failed-precondition',
    ]) {
      if (text.contains(code)) return code;
    }
    return '';
  }

  String messageStreamErrorMessage(Object? error) {
    final code = messagingErrorCode(error);
    final isCurrentUserParticipant = threadParticipants.contains(
      widget.currentUserId,
    );
    switch (code) {
      case 'permission-denied':
        if (isCurrentUserParticipant) {
          return 'Accès refusé par Firestore malgré votre présence dans les participants. Vérifiez App Check ou les règles de lecture.';
        }
        return 'Cette conversation n’est pas disponible pour ce compte.';
      case 'unauthenticated':
        return 'Connectez-vous pour lire cette conversation.';
      case 'not-found':
        return 'Cette conversation n’existe pas encore ou a été supprimée.';
      case 'failed-precondition':
        return 'Cette conversation ne peut pas être chargée dans son état actuel.';
      default:
        return 'Les messages sont temporairement indisponibles. Réessayez dans un instant.';
    }
  }

  String sendMessageErrorMessage(Object? error) {
    if (error is FirebaseFunctionsException) {
      final details = error.details;
      String reason = '';
      if (details is Map) {
        reason = (details['reason'] ?? '').toString().trim();
      }
      switch (reason) {
        case 'messaging_text_blocked':
          return 'Le message contient des termes non conformes aux CGU.';
        case 'messaging_image_blocked':
          return 'Une image du message ne respecte pas les CGU.';
        case 'messaging_content_review_required':
          return 'Le message doit être revu avant de pouvoir être envoyé dans ce mode de modération.';
      }
    }
    final code = messagingErrorCode(error);
    switch (code) {
      case 'not-found':
        return 'La conversation n’existe pas encore. Revenez depuis l’annonce pour la créer avant d’envoyer le premier message.';
      case 'permission-denied':
        return 'Ouverture de la conversation en cours. Ferme puis rouvre la conversation si le message ne part pas.';
      case 'unauthenticated':
        return 'Connectez-vous pour envoyer un message.';
      case 'failed-precondition':
        return 'L’envoi est indisponible car la conversation est bloquée ou incomplète.';
      default:
        return 'L’envoi du message a échoué. Réessayez dans un instant.';
    }
  }

  String attachmentUploadErrorMessage(Object? error) {
    if (error is FirebaseFunctionsException) {
      final details = error.details;
      String reason = '';
      if (details is Map) {
        reason = (details['reason'] ?? '').toString().trim();
      }
      switch (reason) {
        case 'subscription_document_required':
          return 'Les documents et autres fichiers sont réservés à ilipresto+.';
        case 'free_plan_photo_limit_reached':
          return 'Le plan Gratuit est limité à 1 photo par conversation.';
        case 'free_plan_audio_limit_reached':
          return 'Le plan Gratuit est limité à 1 note audio par conversation.';
      }
    }
    final code = messagingErrorCode(error);
    switch (code) {
      case 'unauthenticated':
        return 'Connectez-vous pour envoyer une pièce jointe.';
      case 'permission-denied':
        return 'Vous n’avez pas accès à cette conversation.';
      case 'failed-precondition':
        return 'Cette pièce jointe ne peut pas être envoyée dans l’état actuel de la conversation.';
      case 'resource-exhausted':
        return 'Trop d’envois en peu de temps. Réessayez dans un instant.';
      default:
        return 'La pièce jointe n’a pas pu être envoyée.';
    }
  }

  void _retryMessageStreamAccessAfterDenied(Object? error) {
    if (_messageStreamRetryCount >= 3) return;
    final attempt = ++_messageStreamRetryCount;
    unawaited(() async {
      _debugMessagingAccess(
        'messages-permission-denied-retry-access',
        error: error,
        firestorePath: 'conversations/${widget.conversationId}/messages',
      );
      final delay = Duration(milliseconds: attempt * 600);
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (!mounted) return;
      final ready = await _ensureMessagingAccess(
        interactive: false,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
        requireAppCheckToken: false,
      );
      if (!ready || !mounted) return;
      setState(() {
        _isPreparingMessageStream = false;
        _messageStream = _buildLiveStream(anchorDoc: _paginationAnchorDoc);
      });
    }());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildLiveStream({
    QueryDocumentSnapshot<Map<String, dynamic>>? anchorDoc,
  }) {
    _debugMessagingAccess(
      'build-message-stream',
      firestorePath: 'conversations/${widget.conversationId}/messages',
    );
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true);
    if (anchorDoc != null) {
      query = query.endAtDocument(anchorDoc);
    } else {
      query = query.limit(_messagePageSize);
    }
    return query.snapshots();
  }

  @override
  void initState() {
    // PRESTO_AUTH_PAGE_GUARD_MESSAGES
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AuthGuard.requireVerifiedEmail(context);
    });
    super.initState();
    _loadMostUsedEmojis();
    messageController.addListener(_handleDraftChanged);
    unawaited(_warmMessagingAccess());
    unawaited(_resolveParticipantProfileLookupAccess());
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _presenceSubscription?.cancel();
    _typingStopTimer?.cancel();
    _recordingTimer?.cancel();
    if (_isRecording) {
      unawaited(_cancelVoiceRecording());
    } else {
      _voiceRecorder?.dispose();
    }
    unawaited(_publishTyping(false));
    messageController.removeListener(_handleDraftChanged);
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleDraftChanged() {
    final nextHasDraftText = messageController.text.trim().isNotEmpty;
    if (nextHasDraftText == _hasDraftText) return;
    setState(() {
      _hasDraftText = nextHasDraftText;
    });
    _scheduleTypingUpdate(nextHasDraftText);
  }

  Future<bool> _ensureMessagingAccess({
    required bool interactive,
    bool forceRefreshToken = false,
    bool forceRefreshAppCheckToken = false,
    bool requireAppCheckToken = false,
  }) async {
    try {
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: FirebaseAuth.instance.currentUser,
        forceRefreshToken: forceRefreshToken,
        forceRefreshAppCheckToken: forceRefreshAppCheckToken,
        requireAppCheckToken: requireAppCheckToken,
      );
      return true;
    } catch (error) {
      _debugMessagingAccess(
        'prepare-profile-firestore-access-failed',
        error: error,
        firestorePath: 'conversations/${widget.conversationId}',
      );
      if (interactive && mounted) {
        showErrorSnackBar(
          context,
          UserProfileBootstrapService.userFacingProfileSyncMessage(error),
        );
      }
      return false;
    }
  }

  Future<void> _warmMessagingAccess() async {
    if (mounted) {
      setState(() {
        _isPreparingMessageStream = true;
      });
    }
    var accessAttempt = 0;
    var ready = false;
    while (accessAttempt < 3) {
      ready = await _ensureMessagingAccess(
        interactive: false,
        forceRefreshToken: accessAttempt > 0,
        forceRefreshAppCheckToken: true,
        requireAppCheckToken: false,
      );
      if (ready || !mounted) break;
      accessAttempt++;
      if (accessAttempt < 3) {
        await Future<void>.delayed(Duration(seconds: accessAttempt * 2));
        if (!mounted) return;
      }
    }
    if (!mounted) return;
    if (!ready) {
      setState(() {
        _isPreparingMessageStream = false;
        _messageStream = null;
      });
      return;
    }
    _bindConversationListener();
    setState(() {
      _messageStreamRetryCount = 0;
      _isPreparingMessageStream = false;
      _messageStream = _buildLiveStream(anchorDoc: _paginationAnchorDoc);
    });
  }

  Future<void> _resolveParticipantProfileLookupAccess() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      final accessState = await _adminAccessResolver.resolveAdminAccess(
        returnOnLocalAdminEvidence: true,
      );
      final canLookup = accessState.hasConfirmedAdminAccess;
      final isAdminViewer = accessState.effectiveIsAdmin || canLookup;
      if (!mounted) return;
      if (_canLookupOtherParticipantProfile == canLookup &&
          adminViewerState == isAdminViewer) {
        if (canLookup && _otherParticipantId.trim().isNotEmpty) {
          _bindPresenceListener(_otherParticipantId);
        }
        return;
      }
      setState(() {
        _canLookupOtherParticipantProfile = canLookup;
        adminViewerState = isAdminViewer;
        if (!canLookup) {
          otherPresenceStatus = '';
          otherLastSeenAt = null;
          _otherParticipantPhotoSource = '';
          _otherParticipantPhotoUrl = '';
        }
      });
      if (canLookup && _otherParticipantId.trim().isNotEmpty) {
        _bindPresenceListener(_otherParticipantId);
      } else {
        await _presenceSubscription?.cancel();
        _presenceSubscription = null;
      }
    } catch (error) {
      debugPrint(
        '[ConversationThread] participant profile lookup access check failed '
        'uid=${currentUser.uid} error=$error',
      );
    }
  }

  Widget _buildWatermark() {
    return const _ConversationPatternBackground();
  }

  Widget buildThreadDateChip(DateTime? date) {
    final label = formatThreadDateLabel(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            label,
            style: kPrestoMetaTextStyle.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  bool isSameCalendarDay(DateTime? left, DateTime? right) {
    if (left == null || right == null) return false;
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String conversationInitial() {
    final raw = headerDisplayName.trim();
    if (raw.isEmpty) return '?';
    return raw.characters.first.toUpperCase();
  }

  String get headerOfferTitle {
    final normalized = conversationOfferTitle.trim().isNotEmpty
        ? conversationOfferTitle.trim()
        : widget.offerTitle.trim();
    return normalized.isEmpty ? 'Annonce' : normalized;
  }

  String get headerDisplayName {
    final normalized = otherParticipantNameState.trim();
    return normalized.isEmpty ? headerOfferTitle : normalized;
  }

  String get headerSubtitle {
    if (otherIsTyping) return '$headerDisplayName écrit…';
    final status = otherPresenceStatus.trim().toLowerCase();
    if (status == 'online' && isRecentlySeen(otherLastSeenAt)) {
      return 'en ligne';
    }
    if (otherLastSeenAt != null) {
      return 'vu ${formatPresenceSeenAt(otherLastSeenAt!)}';
    }
    return headerOfferTitle;
  }

  bool isRecentlySeen(DateTime? value) {
    if (value == null) return true;
    return DateTime.now().difference(value.toLocal()) <
        const Duration(minutes: 4);
  }

  String readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Map<String, String> readStringMap(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is! Map) continue;
      final result = <String, String>{};
      for (final entry in raw.entries) {
        final mapKey = entry.key.toString().trim();
        final mapValue = entry.value?.toString().trim() ?? '';
        if (mapKey.isEmpty || mapValue.isEmpty) continue;
        result[mapKey] = mapValue;
      }
      return result;
    }
    return const <String, String>{};
  }

  String firstProfilePhotoValue(Map<String, dynamic> data) {
    for (final key in const [
      'photoUrl',
      'photoURL',
      'profilePhotoUrl',
      'avatarUrl',
      'avatarURL',
      'imageUrl',
    ]) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String firstStoredProfilePhotoPath(Map<String, dynamic> data) {
    return (data['profilePhotoPath'] ?? '').toString().trim();
  }

  bool isResolvableStorageProfilePhoto(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('gs://') || trimmed.startsWith('profilePhotos/');
  }

  bool isNetworkProfilePhoto(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('https://') || trimmed.startsWith('http://');
  }

  Future<void> _resolveOtherParticipantPhoto({
    required String participantId,
    required String storedPath,
    required String currentPhotoValue,
  }) async {
    final source = storedPath.isNotEmpty
        ? storedPath
        : currentPhotoValue.trim();
    if (source.isEmpty || source == _otherParticipantPhotoSource) {
      return;
    }
    if (mounted) {
      setState(() {
        _otherParticipantPhotoSource = source;
        _otherParticipantPhotoUrl = '';
      });
    }
    try {
      final ref = storedPath.isNotEmpty
          ? FirebaseStorage.instance.ref().child(storedPath)
          : FirebaseStorage.instance.refFromURL(currentPhotoValue.trim());
      final downloadUrl = await ref.getDownloadURL().timeout(
        const Duration(seconds: 12),
      );
      final normalizedUrl = downloadUrl.trim();
      if (!mounted ||
          normalizedUrl.isEmpty ||
          _otherParticipantId != participantId ||
          _otherParticipantPhotoSource != source) {
        return;
      }
      setState(() {
        _otherParticipantPhotoUrl = normalizedUrl;
      });
    } catch (error) {
      debugPrint(
        '[ConversationThread] legacy header photo hydration failed '
        'participantId=$participantId path=$storedPath value=$currentPhotoValue '
        'error=$error',
      );
    }
  }

  void _bindPresenceListener(String participantId) {
    if (!_canLookupOtherParticipantProfile) {
      _presenceSubscription?.cancel();
      _presenceSubscription = null;
      return;
    }
    if (participantId.trim().isEmpty || participantId == _otherParticipantId) {
      return;
    }
    _presenceSubscription?.cancel();
    final userDocument = FirebaseFirestore.instance
        .collection('users')
        .doc(participantId);
    _presenceSubscription = userDocument.snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) return;
        final rawPhotoValue = firstProfilePhotoValue(data);
        final storedPath = firstStoredProfilePhotoPath(data);
        final needsStorageResolution =
            (rawPhotoValue.isEmpty && storedPath.isNotEmpty) ||
            isResolvableStorageProfilePhoto(rawPhotoValue);
        final networkPhotoUrl = isNetworkProfilePhoto(rawPhotoValue)
            ? rawPhotoValue.trim()
            : '';
        if (!mounted) return;
        setState(() {
          otherPresenceStatus = (data['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          otherLastSeenAt = parseFirestoreDateTime(data['lastSeenAt']);
          if (!needsStorageResolution) {
            _otherParticipantPhotoSource = networkPhotoUrl;
            _otherParticipantPhotoUrl = networkPhotoUrl;
          }
        });
        if (needsStorageResolution) {
          unawaited(
            _resolveOtherParticipantPhoto(
              participantId: participantId,
              storedPath: storedPath,
              currentPhotoValue: rawPhotoValue,
            ),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _debugMessagingAccess(
          'presence-listen-error',
          error: error,
          firestorePath: 'users/$participantId',
        );
      },
    );
  }

  void _scheduleTypingUpdate(bool isTyping) {
    _typingStopTimer?.cancel();
    unawaited(_publishTyping(isTyping));
    if (!isTyping) return;
    _typingStopTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_publishTyping(false));
    });
  }

  Future<void> _publishTyping(bool isTyping) async {
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update(<String, Object?>{
            'typing.${widget.currentUserId}': isTyping,
            'typingUpdatedAt.${widget.currentUserId}':
                FieldValue.serverTimestamp(),
          });
    } catch (error) {
      debugPrint('[ConversationThread] typing update skipped: $error');
    }
  }

  Future<OfferPreview?> _offerPreviewFor(String offerId) {
    final normalizedOfferId = offerId.trim();
    if (normalizedOfferId.isEmpty) return Future.value(null);
    if (_offerPreviewFutureId == normalizedOfferId &&
        _offerPreviewFuture != null) {
      return _offerPreviewFuture!;
    }
    _offerPreviewFutureId = normalizedOfferId;
    _offerPreviewFuture = _loadOfferPreview(normalizedOfferId);
    return _offerPreviewFuture!;
  }

  Future<OfferPreview?> _loadOfferPreview(String offerId) async {
    for (final collectionName in const ['listings', 'offers']) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(offerId)
            .get();
        final data = snapshot.data();
        if (data != null) {
          return OfferPreview.fromMap(offerId, data);
        }
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied' ||
            error.code == 'unauthenticated') {
          continue;
        }
        rethrow;
      }
    }
    return null;
  }

  void _openLinkedOffer() {
    final normalizedOfferId = _offerId.trim();
    if (normalizedOfferId.isEmpty) return;
    Navigator.of(
      context,
    ).pushNamed('/offers/${Uri.encodeComponent(normalizedOfferId)}');
  }

  Future<void> _openOtherParticipantProfile() async {
    final uid = _otherParticipantId.trim();
    if (uid.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final accountType = (doc.data()?['accountType'] ?? '').toString();
    if (accountType != 'Entreprise') return;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FicheProPage(uid: uid, isOwner: false)),
    );
  }

  Widget _buildThreadAppBarTitle() {
    return GestureDetector(
      onTap: _openOtherParticipantProfile,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: Colors.white,
            foregroundImage: _otherParticipantPhotoUrl.isNotEmpty
                ? profileAvatarImageProvider(_otherParticipantPhotoUrl)
                : null,
            onForegroundImageError: _otherParticipantPhotoUrl.isNotEmpty
                ? (error, stackTrace) {
                    debugPrint(
                      '[ConversationThread] header avatar load failed '
                      'participantId=$_otherParticipantId url=$_otherParticipantPhotoUrl '
                      'error=$error',
                    );
                  }
                : null,
            child: _otherParticipantPhotoUrl.isEmpty
                ? Text(
                    conversationInitial(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kPrestoAppBarTitleStyle,
                ),
                const SizedBox(height: 1),
                Text(
                  _metaLoaded ? headerSubtitle : 'Chargement...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferContextBanner() {
    final normalizedOfferId = _offerId.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: FutureBuilder<OfferPreview?>(
        future: _offerPreviewFor(normalizedOfferId),
        builder: (context, snapshot) {
          final preview =
              snapshot.data ??
              OfferPreview(
                id: normalizedOfferId,
                title: headerOfferTitle,
                priceLabel: '',
                imageUrl: '',
              );
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: preview.imageUrl.isEmpty
                        ? Container(
                            color: const Color(0xFFEAF2FF),
                            child: const Icon(
                              Icons.work_outline_rounded,
                              color: kPrestoBlue,
                              size: 20,
                            ),
                          )
                        : Image(
                            image: CachedNetworkImageProvider(preview.imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFEAF2FF),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: kPrestoBlue,
                                size: 18,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preview.title.isEmpty
                            ? headerOfferTitle
                            : preview.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kPrestoBodyTextStyle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if (_isOfferCardExpanded) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                preview.priceLabel.isEmpty
                                    ? 'Annonce liée à la conversation'
                                    : preview.priceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: kPrestoMetaTextStyle.copyWith(
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (normalizedOfferId.isNotEmpty)
                              TextButton(
                                onPressed: _openLinkedOffer,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Voir',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: kPrestoBlue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _isOfferCardExpanded ? 'Réduire' : 'Déplier',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () => _isOfferCardExpanded = !_isOfferCardExpanded,
                  ),
                  icon: Icon(
                    _isOfferCardExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _bindConversationListener() {
    _conversationSubscription?.cancel();
    final conversationDocument = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);
    _conversationSubscription = conversationDocument.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists) {
          _debugMessagingAccess(
            'conversation-document-not-found',
            firestorePath: 'conversations/${widget.conversationId}',
          );
          _handleConversationRemoved(showMessage: true);
          return;
        }
        final data = snapshot.data();
        if (data == null) return;
        final participants = readConversationParticipants(
          data,
          conversationId: widget.conversationId,
        );
        final isCurrentUserParticipant = participants.contains(
          widget.currentUserId,
        );
        _debugMessagingAccess(
          isCurrentUserParticipant
              ? 'conversation-document-loaded-participant-ok'
              : 'conversation-document-loaded-current-user-missing',
          participants: participants,
          firestorePath: 'conversations/${widget.conversationId}',
        );
        final participantNames = readStringMap(data, const [
          'participantNames',
          'participant_names',
        ]);
        final otherParticipantId = participants.firstWhere(
          (participantId) => participantId != widget.currentUserId,
          orElse: () => '',
        );
        final otherParticipantName =
            (participantNames[otherParticipantId] ?? '').trim().isNotEmpty
            ? participantNames[otherParticipantId]!.trim()
            : readText(data, const ['otherUserName', 'other_user_name']);
        final offerId = readText(data, const [
          'listingId',
          'offerId',
          'offer_id',
        ]);
        final offerTitle = readText(data, const [
          'listingTitle',
          'offerTitle',
          'offer_title',
        ]);
        final typingMap = conversationValue(data, const ['typing']);
        final typingUpdatedAtMap = conversationValue(data, const [
          'typingUpdatedAt',
        ]);
        var isOtherTyping = false;
        if (typingMap is Map) {
          final rawTyping = typingMap[otherParticipantId] == true;
          final updatedAt = typingUpdatedAtMap is Map
              ? parseFirestoreDateTime(typingUpdatedAtMap[otherParticipantId])
              : null;
          isOtherTyping =
              rawTyping &&
              (updatedAt == null ||
                  DateTime.now().difference(updatedAt.toLocal()) <
                      const Duration(seconds: 8));
        }
        _bindPresenceListener(otherParticipantId);
        final unreadMap = conversationValue(data, const [
          'unreadCount',
          'unread_count',
        ]);
        final unreadCount = unreadMap is Map<String, dynamic>
            ? ((unreadMap[widget.currentUserId] as int?) ?? 0)
            : unreadMap is Map
            ? ((unreadMap[widget.currentUserId] as num?)?.toInt() ?? 0)
            : 0;
        final participantChanged = otherParticipantId != _otherParticipantId;
        final isDeletedForCurrentUser = isConversationDeletedForUser(
          data,
          widget.currentUserId,
        );
        if (mounted) {
          setState(() {
            threadParticipants = participants;
            _participantNames = participantNames;
            _otherParticipantId = otherParticipantId;
            otherParticipantNameState = otherParticipantName;
            if (participantChanged) {
              _otherParticipantPhotoSource = '';
              _otherParticipantPhotoUrl = '';
            }
            _offerId = offerId;
            conversationOfferTitle = offerTitle;
            otherIsTyping = isOtherTyping;
            final lastReadAt = conversationValue(data, const [
              'lastReadAt',
              'last_read_at',
            ]);
            threadLastReadAt = lastReadAt is Map<String, dynamic>
                ? lastReadAt
                : lastReadAt is Map
                ? Map<String, dynamic>.from(lastReadAt)
                : const {};
            _metaLoaded = true;
            conversationBlocked = isConversationBlocked(data);
            blockedForCurrentUser = isConversationBlockedForUser(
              data,
              widget.currentUserId,
            );
            blockedByAnotherParticipant = isConversationBlockedByOtherUser(
              data,
              widget.currentUserId,
            );
            archivedForCurrentUser = isConversationArchivedForUser(
              data,
              widget.currentUserId,
            );
            _isDeletedForCurrentUser = isDeletedForCurrentUser;
          });
        }
        if (isDeletedForCurrentUser) {
          _handleConversationRemoved(showMessage: false);
          return;
        }
        if (unreadCount > 0) {
          _markAsRead();
        }
      },
      onError: (error, stackTrace) {
        _debugMessagingAccess(
          'conversation-document-listen-error',
          error: error,
          firestorePath: 'conversations/${widget.conversationId}',
        );
      },
    );
  }

  void _handleConversationRemoved({required bool showMessage}) {
    if (_hasHandledConversationRemoval || !mounted) return;
    _hasHandledConversationRemoval = true;
    if (showMessage) {
      showErrorSnackBar(context, 'Conversation introuvable ou supprimée.');
    }
    Navigator.of(context).maybePop();
  }

  String? readReceiptLabel(DateTime? sentAt) {
    if (sentAt == null) return null;
    final otherParticipantId = threadParticipants.firstWhere(
      (participantId) => participantId != widget.currentUserId,
      orElse: () => '',
    );
    if (otherParticipantId.isEmpty) return null;
    final raw = threadLastReadAt[otherParticipantId];
    final readAt = parseFirestoreDateTime(raw);
    if (readAt == null || readAt.isBefore(sentAt)) return null;
    return 'Vu';
  }

  Future<void> _markAsRead() async {
    if (_isMarkingRead) return;
    _isMarkingRead = true;
    try {
      final ready = await _ensureMessagingAccess(interactive: false);
      if (!ready) return;
      await ConversationService.markAsRead(
        conversationId: widget.conversationId,
      );
    } catch (e) {
      debugPrint('[ConversationThread] _markAsRead error: $e');
    } finally {
      _isMarkingRead = false;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergeMessageDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> liveDocs,
  ) {
    final merged = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final seenIds = <String>{};
    for (final doc in [...liveDocs, ..._olderMessageDocs]) {
      if (seenIds.add(doc.id)) {
        merged.add(doc);
      }
    }
    return merged;
  }

  Future<void> _loadMoreMessages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> liveDocs,
  ) async {
    if (_isLoadingMoreMessages) return;
    final ready = await _ensureMessagingAccess(interactive: true);
    if (!ready) return;
    // Cursor : oldest doc in older pages already loaded, or oldest live doc.
    final cursor = _olderMessageDocs.isNotEmpty
        ? _olderMessageDocs.last
        : liveDocs.isNotEmpty
        ? liveDocs.last
        : null;
    if (cursor == null) return;
    setState(() {
      _isLoadingMoreMessages = true;
    });
    // On first pagination: anchor the live stream to avoid gaps when new
    // messages push older docs outside the .limit() window.
    final isFirstPagination =
        _paginationAnchorDoc == null && _olderMessageDocs.isEmpty;
    final anchorDoc = isFirstPagination
        ? (liveDocs.isNotEmpty ? liveDocs.last : null)
        : _paginationAnchorDoc;
    try {
      final olderSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cursor)
          .limit(_messagePageSize)
          .get();
      final fetchedDocs = olderSnapshot.docs;
      if (!mounted) return;
      setState(() {
        if (isFirstPagination && anchorDoc != null) {
          _paginationAnchorDoc = anchorDoc;
          _messageStream = _buildLiveStream(anchorDoc: anchorDoc);
        }
        final existingIds = _olderMessageDocs.map((doc) => doc.id).toSet();
        for (final doc in fetchedDocs) {
          if (!existingIds.contains(doc.id)) {
            _olderMessageDocs.add(doc);
          }
        }
        _hasAttemptedOlderPagination = true;
        _hasMoreMessages = fetchedDocs.length == _messagePageSize;
      });
    } catch (e) {
      debugPrint('[ConversationThread] _loadMoreMessages error: $e');
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'Les messages plus anciens sont temporairement indisponibles.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreMessages = false;
        });
      }
    }
  }

  Future<String> _sendMessageCf({
    required String text,
    List<ConversationAttachmentInput> attachments = const [],
  }) async {
    Object? firstError;
    try {
      return await ConversationService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        attachments: attachments,
      );
    } catch (error) {
      if (messagingErrorCode(error) != 'unauthenticated') rethrow;
      firstError = error;
    }
    // Auth token may have expired — refresh and retry once
    final retryReady = await _ensureMessagingAccess(
      interactive: false,
      forceRefreshToken: true,
      forceRefreshAppCheckToken: true,
    );
    if (!retryReady) throw firstError;
    return await ConversationService.sendMessage(
      conversationId: widget.conversationId,
      text: text,
      attachments: attachments,
    );
  }

  Future<void> _switchToConversationIfNeeded(String conversationId) async {
    final normalizedConversationId = conversationId.trim();
    if (!mounted ||
        normalizedConversationId.isEmpty ||
        normalizedConversationId == widget.conversationId) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ConversationThreadPage(
          conversationId: normalizedConversationId,
          offerTitle: conversationOfferTitle.isNotEmpty
              ? conversationOfferTitle
              : widget.offerTitle,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final rawDraft = messageController.text;
    final text = rawDraft.trim();
    if (text.isEmpty || _isSending) return;
    if (conversationBlocked) {
      showErrorSnackBar(
        context,
        'L envoi est indisponible tant que cette conversation est bloquee.',
      );
      return;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      showErrorSnackBar(context, 'Connectez-vous pour envoyer un message.');
      return;
    }
    final optimisticMessage = OptimisticMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      sentAt: DateTime.now(),
      senderName: authUser.displayName?.trim() ?? '',
      status: OptimisticMessageStatus.sending,
    );
    setState(() {
      _isSending = true;
      _hasDraftText = false;
      _optimisticMessages.insert(0, optimisticMessage);
    });
    messageController.clear();
    _scheduleTypingUpdate(false);
    _scrollToLatestMessage(force: true);
    try {
      final ready = await _ensureMessagingAccess(interactive: true);
      if (!ready) {
        _markOptimisticMessageFailed(optimisticMessage.id);
        if (messageController.text.trim().isEmpty) {
          messageController.value = TextEditingValue(
            text: rawDraft,
            selection: TextSelection.collapsed(offset: rawDraft.length),
          );
        }
        return;
      }
      final resolvedConversationId = await _sendMessageCf(text: text);
      if (resolvedConversationId == widget.conversationId) {
        unawaited(_markAsRead());
      }
      _removeOptimisticMessage(optimisticMessage.id);
      await _switchToConversationIfNeeded(resolvedConversationId);
      if (!mounted) return;
      _scrollToLatestMessage(force: true);
    } catch (error) {
      _debugMessagingAccess(
        'send-message-failed',
        error: error,
        firestorePath: 'conversations/${widget.conversationId}',
      );
      if (!mounted) return;
      _markOptimisticMessageFailed(optimisticMessage.id);
      if (messageController.text.trim().isEmpty) {
        messageController.value = TextEditingValue(
          text: rawDraft,
          selection: TextSelection.collapsed(offset: rawDraft.length),
        );
      }
      showErrorSnackBar(context, sendMessageErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  bool _isNearLatestMessage() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset <= 96;
  }

  void _scrollToLatestMessage({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!force && !_isNearLatestMessage()) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      if (mounted && _showNewMessagesButton) {
        setState(() => _showNewMessagesButton = false);
      }
    });
  }

  void _handleLiveMessageDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> liveDocs,
  ) {
    if (liveDocs.isEmpty) return;
    final newestDoc = liveDocs.first;
    if (_newestLiveMessageId == null) {
      _newestLiveMessageId = newestDoc.id;
      return;
    }
    if (_newestLiveMessageId == newestDoc.id) return;
    _newestLiveMessageId = newestDoc.id;
    final data = newestDoc.data();
    final senderId = ((data['senderId'] ?? data['sender_id']) ?? '').toString();
    if (senderId == widget.currentUserId || _isNearLatestMessage()) {
      _scrollToLatestMessage();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showNewMessagesButton = true);
    });
  }

  void _removeOptimisticMessage(String id) {
    if (!mounted) return;
    setState(() {
      _optimisticMessages.removeWhere((message) => message.id == id);
    });
  }

  void _markOptimisticMessageFailed(String id) {
    if (!mounted) return;
    setState(() {
      final index = _optimisticMessages.indexWhere(
        (message) => message.id == id,
      );
      if (index < 0) return;
      _optimisticMessages[index] = _optimisticMessages[index].copyWith(
        status: OptimisticMessageStatus.failed,
      );
    });
  }

  Future<void> _retryOptimisticMessage(OptimisticMessage message) async {
    if (_isSending || conversationBlocked) return;
    setState(() {
      _isSending = true;
      final index = _optimisticMessages.indexWhere(
        (item) => item.id == message.id,
      );
      if (index >= 0) {
        _optimisticMessages[index] = message.copyWith(
          status: OptimisticMessageStatus.sending,
        );
      }
    });
    try {
      final ready = await _ensureMessagingAccess(interactive: true);
      if (!ready) {
        _markOptimisticMessageFailed(message.id);
        return;
      }
      await _sendMessageCf(
        text: message.text,
        attachments: message.attachments
            .map((attachment) => attachment.toInput())
            .toList(),
      );
      unawaited(_markAsRead());
      _removeOptimisticMessage(message.id);
      _scrollToLatestMessage(force: true);
    } catch (error) {
      debugPrint('[ConversationThread] retry send error: $error');
      _markOptimisticMessageFailed(message.id);
      if (!mounted) return;
      showErrorSnackBar(context, 'Le message n’a pas pu être renvoyé.');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _handleConversationAction(
    _ConversationThreadAction action,
  ) async {
    try {
      final ready = await _ensureMessagingAccess(interactive: true);
      if (!mounted) return;
      if (!ready) return;
      switch (action) {
        case _ConversationThreadAction.archive:
          await ConversationService.archiveConversation(
            conversationId: widget.conversationId,
          );
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation archivee.');
          return;
        case _ConversationThreadAction.unarchive:
          await ConversationService.unarchiveConversation(
            conversationId: widget.conversationId,
          );
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation restauree.');
          return;
        case _ConversationThreadAction.block:
          await ConversationService.blockConversation(
            conversationId: widget.conversationId,
          );
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation bloquee.');
          return;
        case _ConversationThreadAction.unblock:
          await ConversationService.unblockConversation(
            conversationId: widget.conversationId,
          );
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation debloquee.');
          return;
        case _ConversationThreadAction.adminUnblock:
          await ConversationService.adminUnblockConversation(
            conversationId: widget.conversationId,
          );
          if (!mounted) return;
          setState(() {
            conversationBlocked = false;
            blockedForCurrentUser = false;
            blockedByAnotherParticipant = false;
          });
          showSuccessSnackBar(context, 'Conversation debloquee par admin.');
          return;
        case _ConversationThreadAction.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              final overlayTheme = ctx.prestoOverlayTheme;
              return AlertDialog(
                icon: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF6600),
                  size: 38,
                ),
                backgroundColor: overlayTheme.surfaceColor,
                surfaceTintColor: overlayTheme.surfaceTintColor,
                shape: overlayTheme.dialogShape,
                title: const Text('Supprimer la conversation'),
                content: const Text(
                  'Cette conversation sera retirée uniquement de votre messagerie. L’autre participant continuera à la voir tant qu’il ne la supprime pas lui-même.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Supprimer'),
                  ),
                ],
              );
            },
          );
          if (confirmed != true || !mounted) return;
          await ConversationService.deleteConversation(
            conversationId: widget.conversationId,
          );
          if (!mounted) return;
          _hasHandledConversationRemoval = true;
          showSuccessSnackBar(
            context,
            'Conversation supprimée pour votre compte.',
          );
          Navigator.of(context).pop();
          return;
      }
    } catch (error) {
      if (!mounted) return;
      debugPrint(
        '[ConversationThread] conversation action failed id=${widget.conversationId} action=$action error=$error',
      );
      showErrorSnackBar(
        context,
        'Cette action est temporairement indisponible. Reessayez dans un instant.',
      );
    }
  }

  Widget buildStateBanner() {
    if (conversationBlocked) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: _ConversationBanner(
          icon: Icons.block_rounded,
          color: const Color(0xFFFF0000),
          message: blockedForCurrentUser
              ? 'Vous avez bloque cette conversation. Debloquez-la pour reprendre les echanges.'
              : blockedByAnotherParticipant
              ? adminViewerState
                    ? 'Cette conversation a ete bloquee par un participant. Un admin peut la debloquer.'
                    : 'Cette conversation a ete bloquee par l autre participant.'
              : 'Cette conversation est actuellement bloquee.',
        ),
      );
    }
    if (archivedForCurrentUser) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: _ConversationBanner(
          icon: Icons.archive_outlined,
          color: Color(0xFF6B7280),
          message:
              'Conversation archivee pour vous. Un nouveau message la restaurera automatiquement.',
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void applyInitialDraftIfNeeded(bool hasMessages) {
    if (didApplyInitialDraft || hasMessages) return;
    final initialDraft = widget.initialDraftText?.trim() ?? '';
    if (initialDraft.isEmpty || messageController.text.trim().isNotEmpty) {
      didApplyInitialDraft = true;
      return;
    }
    didApplyInitialDraft = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      messageController.value = TextEditingValue(
        text: initialDraft,
        selection: TextSelection.collapsed(offset: initialDraft.length),
      );
    });
  }

  Widget buildSafetyReminderBanner() {
    if (!showSafetyReminder) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFFF0000), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              color: Color(0xFFFF0000),
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ne partagez jamais de codes, mots de passe ou informations bancaires.',
                style: kPrestoMetaTextStyle.copyWith(
                  color: const Color(0xFFFF0000),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Masquer',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => showSafetyReminder = false),
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFFFF0000),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTypingIndicator() {
    if (!otherIsTyping) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            '$headerDisplayName écrit…',
            style: kPrestoMetaTextStyle.copyWith(
              color: kWhatsappGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadMostUsedEmojis() async {
    if (_didLoadEmojiUsage) return;
    _didLoadEmojiUsage = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() => _quickEmojis = _defaultQuickEmojis);
      }
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final rawUsage = snapshot.data()?['messageEmojiUsage'];

      final usage = <String, int>{};
      if (rawUsage is Map) {
        rawUsage.forEach((key, value) {
          final emoji = key.toString().trim();
          if (emoji.isEmpty) return;

          final count = value is num ? value.toInt() : int.tryParse('$value');
          if (count == null || count <= 0) return;

          usage[emoji] = count;
        });
      }

      final sorted = usage.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });

      final next = <String>[
        ...sorted.map((entry) => entry.key),
        ..._defaultQuickEmojis,
      ];

      final uniqueTop6 = <String>[];
      for (final emoji in next) {
        if (uniqueTop6.contains(emoji)) continue;
        uniqueTop6.add(emoji);
        if (uniqueTop6.length >= 6) break;
      }

      if (!mounted) return;
      setState(() {
        _emojiUsageCounts = usage;
        _quickEmojis = uniqueTop6.isEmpty ? _defaultQuickEmojis : uniqueTop6;
      });
    } catch (error) {
      debugPrint(
        '[ConversationThread] Chargement emojis fréquents ignoré: $error',
      );
      if (!mounted) return;
      setState(() => _quickEmojis = _defaultQuickEmojis);
    }
  }

  Future<void> _recordEmojiUsage(String emoji) async {
    final cleanEmoji = emoji.trim();
    if (cleanEmoji.isEmpty) return;

    final nextUsage = Map<String, int>.from(_emojiUsageCounts);
    nextUsage[cleanEmoji] = (nextUsage[cleanEmoji] ?? 0) + 1;

    final sorted = nextUsage.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    final nextQuickEmojis = sorted.map((entry) => entry.key).take(6).toList();

    if (mounted) {
      setState(() {
        _emojiUsageCounts = nextUsage;
        _quickEmojis = nextQuickEmojis.isEmpty
            ? _defaultQuickEmojis
            : [...nextQuickEmojis, ..._defaultQuickEmojis].fold<List<String>>(
                <String>[],
                (list, item) {
                  if (!list.contains(item) && list.length < 6) {
                    list.add(item);
                  }
                  return list;
                },
              );
      });
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'messageEmojiUsage': {cleanEmoji: FieldValue.increment(1)},
        'messageEmojiUsageUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint(
        '[ConversationThread] Sauvegarde emoji fréquent ignorée: $error',
      );
    }
  }

  Widget _buildEmojiStrip() {
    if (!_showEmojiStrip || conversationBlocked) return const SizedBox.shrink();

    final emojis = _quickEmojis.take(6).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final emoji in emojis)
                InkWell(
                  onTap: () => _insertEmoji(emoji),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 19)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagingSubscriptionBadge() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<SubscriptionAppConfig>(
      stream: _subscriptionConfigService.watchConfig(),
      builder: (context, configSnapshot) {
        final config =
            configSnapshot.data ?? const SubscriptionAppConfig.defaults();

        if (config.freeAccessMode) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            final userState = AppUserSubscriptionState.fromMap(
              userSnapshot.data?.data(),
            );
            final entitlements = getConversationAttachmentEntitlements(
              userState.plan,
              freeAccessMode: config.freeAccessMode,
            );

            final message = entitlements.canSendDocuments
                ? 'ilipresto+ actif pour cette conversation: fichiers, photos et audio débloqués.'
                : 'Gratuit: 1 photo + 1 audio par conversation. Les documents demandent ilipresto+.';

            final accentColor = entitlements.canSendDocuments
                ? kPrestoBlue
                : kPrestoOrange;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: kPrestoMetaTextStyle.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _insertEmoji(String emoji) {
    unawaited(_recordEmojiUsage(emoji));
    final selection = messageController.selection;
    final text = messageController.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  String safeAttachmentName(String name, String fallback) {
    final cleaned = name.trim().isEmpty ? fallback : name.trim();
    final sanitized = cleaned
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (sanitized.isNotEmpty) return sanitized;
    return fallback
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), 'piece-jointe');
  }

  String mimeTypeForName(String name, String fallback) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.gif')) return 'image/gif';
    if (lowerName.endsWith('.mp3')) return 'audio/mpeg';
    if (lowerName.endsWith('.wav')) return 'audio/wav';
    if (lowerName.endsWith('.ogg')) return 'audio/ogg';
    if (lowerName.endsWith('.oga')) return 'audio/ogg';
    if (lowerName.endsWith('.m4a')) return 'audio/mp4';
    if (lowerName.endsWith('.aac')) return 'audio/aac';
    if (lowerName.endsWith('.webm')) return 'audio/webm';
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.csv')) return 'text/csv';
    if (lowerName.endsWith('.txt')) return 'text/plain';
    if (lowerName.endsWith('.rtf')) return 'application/rtf';
    if (lowerName.endsWith('.doc')) return 'application/msword';
    if (lowerName.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lowerName.endsWith('.odt')) {
      return 'application/vnd.oasis.opendocument.text';
    }
    if (lowerName.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lowerName.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lowerName.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lowerName.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    return fallback;
  }

  String attachmentTypeForFile(String name, String mimeType) {
    final normalizedMimeType = mimeType.trim().toLowerCase();
    final lowerName = name.trim().toLowerCase();
    if (normalizedMimeType.startsWith('audio/')) {
      return 'audio';
    }
    if (lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.wav') ||
        lowerName.endsWith('.ogg') ||
        lowerName.endsWith('.oga') ||
        lowerName.endsWith('.m4a') ||
        lowerName.endsWith('.aac') ||
        lowerName.endsWith('.webm')) {
      return 'audio';
    }
    return 'document';
  }

  String attachmentMessageText(MessageAttachment attachment) {
    if (attachment.type == 'image') return 'Photo : ${attachment.name}';
    if (attachment.type == 'audio') return 'Note vocale';
    return 'Document : ${attachment.name}';
  }

  bool shouldHideAttachmentText(
    String text,
    List<MessageAttachment> attachments,
  ) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty || attachments.isEmpty) {
      return false;
    }
    if (attachments.any((attachment) => attachment.type != 'image')) {
      return false;
    }
    return normalizedText == attachmentMessageText(attachments.first);
  }

  Future<void> _pickAndSendPhoto() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      showErrorSnackBar(context, 'Connectez-vous pour envoyer une photo.');
      return;
    }
    final allowed = await _ensureAttachmentAllowed(
      uid: authUser.uid,
      attachmentType: 'image',
    );
    if (!allowed) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1920,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final name = safeAttachmentName(picked.name, 'photo.jpg');
    await _uploadAndSendAttachment(
      uid: authUser.uid,
      type: 'image',
      name: name,
      bytes: bytes,
      mimeType: picked.mimeType ?? mimeTypeForName(name, 'image/jpeg'),
    );
  }

  Future<void> _pickAndSendDocument() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      showErrorSnackBar(context, 'Connectez-vous pour envoyer un fichier.');
      return;
    }
    final allowed = await _ensureAttachmentAllowed(
      uid: authUser.uid,
      attachmentType: 'document',
    );
    if (!allowed) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'txt',
        'csv',
        'rtf',
        'doc',
        'docx',
        'odt',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'mp3',
        'wav',
        'ogg',
        'oga',
        'm4a',
        'aac',
        'webm',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Ce fichier ne peut pas être lu.');
      return;
    }

    final name = safeAttachmentName(file.name, 'document.pdf');
    final mimeType = mimeTypeForName(name, 'application/pdf');
    final attachmentType = attachmentTypeForFile(name, mimeType);
    await _uploadAndSendAttachment(
      uid: authUser.uid,
      type: attachmentType,
      name: name,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  Future<ProcessedConversationPhoto> _processPhotoWithRetry(
    String storagePath,
  ) async {
    try {
      return await ConversationService.processConversationPhoto(
        conversationId: widget.conversationId,
        storagePath: storagePath,
      );
    } catch (_) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) rethrow;
      await _ensureMessagingAccess(
        interactive: false,
        forceRefreshToken: true,
        forceRefreshAppCheckToken: true,
        requireAppCheckToken: false,
      );
      return ConversationService.processConversationPhoto(
        conversationId: widget.conversationId,
        storagePath: storagePath,
      );
    }
  }

  Future<void> _uploadAndSendAttachment({
    required String uid,
    required String type,
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (_isUploadingAttachment || _isSending) return;
    if (conversationBlocked) {
      showErrorSnackBar(
        context,
        'L envoi est indisponible tant que cette conversation est bloquee.',
      );
      return;
    }
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      showErrorSnackBar(context, 'La pièce jointe dépasse 20 Mo.');
      return;
    }

    setState(() => _isUploadingAttachment = true);

    try {
      final ready = await _ensureMessagingAccess(interactive: true);
      if (!ready) return;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          'messageAttachments/$uid/${widget.conversationId}/'
          '${timestamp}_${safeAttachmentName(name, 'piece-jointe')}';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(bytes, SettableMetadata(contentType: mimeType));
      var attachmentName = name;
      var attachmentPath = path;
      var attachmentMimeType = mimeType;
      var attachmentSizeBytes = bytes.lengthInBytes;
      var url = await ref.getDownloadURL();

      if (type == 'image') {
        final processed = await _processPhotoWithRetry(path);
        attachmentName = name.replaceFirst(RegExp(r'\.[^/.]+$'), '.webp');
        attachmentPath = processed.storagePath;
        attachmentMimeType = processed.mimeType;
        attachmentSizeBytes = processed.sizeBytes;
        url = processed.thumbnailUrl.trim().isNotEmpty
            ? processed.thumbnailUrl
            : processed.downloadUrl;
      }

      final attachment = MessageAttachment(
        type: type,
        name: attachmentName,
        url: url,
        storagePath: attachmentPath,
        mimeType: attachmentMimeType,
        sizeBytes: attachmentSizeBytes,
      );
      await _sendAttachmentMessage(attachment);
    } catch (error) {
      debugPrint('[ConversationThread] attachment upload error: $error');
      if (!mounted) return;
      showErrorSnackBar(context, attachmentUploadErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  Future<void> _sendAttachmentMessage(MessageAttachment attachment) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final draftText = messageController.text.trim();
    final text = draftText.isEmpty
        ? attachmentMessageText(attachment)
        : draftText;
    final optimisticMessage = OptimisticMessage(
      id: 'local-attachment-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      attachments: [attachment],
      sentAt: DateTime.now(),
      senderName: authUser.displayName?.trim() ?? '',
      status: OptimisticMessageStatus.sending,
    );

    setState(() {
      _isSending = true;
      if (draftText.isNotEmpty) {
        messageController.clear();
        _hasDraftText = false;
      }
      _optimisticMessages.insert(0, optimisticMessage);
    });
    _scrollToLatestMessage(force: true);

    try {
      final resolvedConversationId = await ConversationService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        attachments: [attachment.toInput()],
      );
      if (resolvedConversationId == widget.conversationId) {
        unawaited(_markAsRead());
      }
      _removeOptimisticMessage(optimisticMessage.id);
      await _switchToConversationIfNeeded(resolvedConversationId);
      if (!mounted) return;
      _scrollToLatestMessage(force: true);
    } catch (error) {
      debugPrint('[ConversationThread] send attachment error: $error');
      _markOptimisticMessageFailed(optimisticMessage.id);
      if (!mounted) return;
      showErrorSnackBar(
        context,
        'La pièce jointe est prête mais l’envoi a échoué.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_outlined, color: kPrestoBlue),
                title: const Text('Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickAndSendPhoto());
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: kPrestoBlue,
                ),
                title: const Text('Fichier'),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickAndSendDocument());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showVoiceRecordingSheet() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      showErrorSnackBar(
        context,
        'Connectez-vous pour envoyer une note vocale.',
      );
      return;
    }
    final allowed = await _ensureAttachmentAllowed(
      uid: authUser.uid,
      attachmentType: 'audio',
    );
    if (!allowed) return;

    if (kIsWeb) {
      try {
        await _webVoiceRecorder.start();
      } catch (_) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Impossible de démarrer l\'enregistrement dans le navigateur.',
          );
        }
        return;
      }
      if (!mounted) {
        try {
          await _webVoiceRecorder.stopToBlob();
        } catch (_) {}
        return;
      }
      setState(() {
        _isRecording = true;
        _isWebVoiceRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordingDuration += const Duration(seconds: 1));
      });
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _VoiceRecordingSheet(
          onCancel: () {
            Navigator.of(ctx).pop();
            unawaited(_cancelVoiceRecording());
          },
          onSend: () {
            Navigator.of(ctx).pop();
            unawaited(_stopVoiceRecordingForPreview());
          },
        ),
      );
      if (_isRecording) {
        unawaited(_cancelVoiceRecording());
      }
      return;
    }

    final recorder = AudioRecorder();
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      recorder.dispose();
      if (mounted) {
        showErrorSnackBar(context, 'Permission microphone refusée.');
      }
      return;
    }
    String path;
    try {
      path = await createTempAudioPath(prefix: 'note_vocale', extension: 'm4a');
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacEld,
          sampleRate: 16000,
          bitRate: 32000,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (_) {
      recorder.dispose();
      if (mounted) {
        showErrorSnackBar(context, "Impossible de démarrer l'enregistrement.");
      }
      return;
    }
    if (!mounted) {
      try {
        await recorder.stop();
      } catch (_) {}
      recorder.dispose();
      return;
    }
    setState(() {
      _isRecording = true;
      _isWebVoiceRecording = false;
      _voiceRecorder = recorder;
      _currentRecordingPath = path;
      _recordingDuration = Duration.zero;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingDuration += const Duration(seconds: 1));
    });
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VoiceRecordingSheet(
        onCancel: () {
          Navigator.of(ctx).pop();
          unawaited(_cancelVoiceRecording());
        },
        onSend: () {
          Navigator.of(ctx).pop();
          unawaited(_stopVoiceRecordingForPreview());
        },
      ),
    );
    if (_isRecording) {
      unawaited(_cancelVoiceRecording());
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final isWebVoiceRecording = _isWebVoiceRecording;
    final recorder = _voiceRecorder;
    final path = _currentRecordingPath;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isWebVoiceRecording = false;
        _voiceRecorder = null;
        _currentRecordingPath = null;
        _recordingDuration = Duration.zero;
      });
    }
    if (isWebVoiceRecording) {
      try {
        await _webVoiceRecorder.stopToBlob();
      } catch (_) {}
      return;
    }
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (_) {}
      recorder.dispose();
    }
    if (path != null) {
      deleteTempFile(path);
    }
  }

  Future<void> _stopVoiceRecordingForPreview() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final isWebVoiceRecording = _isWebVoiceRecording;
    final recorder = _voiceRecorder;
    final path = _currentRecordingPath;
    final duration = _recordingDuration;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isWebVoiceRecording = false;
        _voiceRecorder = null;
        _currentRecordingPath = null;
        _recordingDuration = Duration.zero;
      });
    }
    if (isWebVoiceRecording) {
      try {
        final blob = await _webVoiceRecorder.stopToBlob();
        final audioUpload = await webBlobToMicroIaUpload(
          blob,
          preferRawBytes: true,
        );
        if (audioUpload.bytes.isEmpty) {
          throw Exception('Audio invalide');
        }
        final previewSource = await createLocalAudioPreviewSource(
          audioUpload.bytes,
          contentType: audioUpload.contentType,
        );
        if (!mounted) {
          disposeLocalAudioPreviewSource(previewSource);
          return;
        }
        await _showVoiceNotePreviewSheet(
          _PendingVoiceNote(
            duration: duration,
            bytes: audioUpload.bytes,
            previewSource: previewSource,
            previewIsLocalFile: false,
            mimeType: audioUpload.contentType,
            extension: audioUpload.extension.trim().isEmpty
                ? 'webm'
                : audioUpload.extension.trim(),
            usesGeneratedPreviewSource: true,
          ),
        );
      } catch (_) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Erreur lors de la préparation de la note vocale.',
          );
        }
      }
      return;
    }

    if (recorder == null || path == null) return;
    try {
      await recorder.stop();
    } catch (_) {}
    recorder.dispose();
    if (!mounted) {
      deleteTempFile(path);
      return;
    }
    await _showVoiceNotePreviewSheet(
      _PendingVoiceNote(
        duration: duration,
        filePath: path,
        previewSource: path,
        previewIsLocalFile: true,
        mimeType: 'audio/mp4',
        extension: 'm4a',
      ),
    );
  }

  Future<void> _showVoiceNotePreviewSheet(_PendingVoiceNote preview) async {
    final action = await showModalBottomSheet<_VoiceNotePreviewAction>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VoiceNotePreviewSheet(
        preview: preview,
        onCancel: () => Navigator.of(ctx).pop(_VoiceNotePreviewAction.cancel),
        onRerecord: () =>
            Navigator.of(ctx).pop(_VoiceNotePreviewAction.rerecord),
        onSend: () => Navigator.of(ctx).pop(_VoiceNotePreviewAction.send),
      ),
    );

    switch (action) {
      case _VoiceNotePreviewAction.send:
        await _sendPreparedVoiceNote(preview);
        await _disposePendingVoiceNote(preview);
        return;
      case _VoiceNotePreviewAction.rerecord:
        await _disposePendingVoiceNote(preview);
        if (mounted) {
          await _showVoiceRecordingSheet();
        }
        return;
      case _VoiceNotePreviewAction.cancel:
      case null:
        await _disposePendingVoiceNote(preview);
        return;
    }
  }

  Future<void> _sendPreparedVoiceNote(_PendingVoiceNote preview) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Connectez-vous pour envoyer une note vocale.',
        );
      }
      return;
    }

    Uint8List bytes;
    if (preview.bytes != null) {
      bytes = preview.bytes!;
    } else {
      final path = preview.filePath;
      if (path == null) return;
      try {
        bytes = await readTempFile(path);
      } catch (_) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Erreur lors de la lecture de la note vocale.',
          );
        }
        return;
      }
    }

    final secs = preview.duration.inSeconds;
    final safeSeconds = secs <= 0 ? 1 : secs;
    final extension = preview.extension.trim().isEmpty
        ? 'm4a'
        : preview.extension.trim();
    final name = 'note_vocale_${safeSeconds}s.$extension';
    await _uploadAndSendAttachment(
      uid: authUser.uid,
      type: 'audio',
      name: name,
      bytes: bytes,
      mimeType: preview.mimeType,
    );
  }

  Future<void> _disposePendingVoiceNote(
    _PendingVoiceNote preview, {
    bool keepFilePath = false,
  }) async {
    if (preview.usesGeneratedPreviewSource) {
      disposeLocalAudioPreviewSource(preview.previewSource);
    }
    if (!keepFilePath && preview.filePath != null) {
      deleteTempFile(preview.filePath!);
    }
  }

  Future<void> _openAttachment(MessageAttachment attachment) async {
    if (attachment.type == 'image') {
      return;
    }
    await _showAttachmentActionsSheet(attachment);
  }

  Future<void> _showAttachmentActionsSheet(MessageAttachment attachment) async {
    final overlayTheme = context.prestoOverlayTheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: overlayTheme.surfaceColor,
      shape: overlayTheme.sheetShape,
      builder: (sheetContext) {
        Future<void> handleOpen() async {
          Navigator.of(sheetContext).pop();
          await _openAttachmentWithChooser(attachment);
        }

        Future<void> handleShare() async {
          Navigator.of(sheetContext).pop();
          await _shareAttachment(attachment);
        }

        return SafeArea(
          top: false,
          child: Container(
            color: overlayTheme.surfaceColor,
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pièce jointe',
                  textAlign: TextAlign.center,
                  style: kPrestoSectionTitleStyle,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: overlayTheme.selectionFillColor,
                    borderRadius: overlayTheme.popupRadius,
                    border: Border.all(color: overlayTheme.borderColor),
                  ),
                  child: Text(
                    attachment.name,
                    style: kPrestoBodyTextStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _AttachmentActionTile(
                  icon: Icons.open_in_new_rounded,
                  title: 'Ouvrir',
                  subtitle: kIsWeb
                      ? 'Ouvre le fichier dans le navigateur.'
                      : 'Télécharge puis laisse choisir l’application.',
                  onTap: handleOpen,
                ),
                const SizedBox(height: 8),
                _AttachmentActionTile(
                  icon: Icons.share_rounded,
                  title: 'Partager',
                  subtitle: kIsWeb
                      ? 'Partage le lien du fichier.'
                      : 'Partage le fichier avec une autre application.',
                  onTap: handleShare,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAttachmentWithChooser(MessageAttachment attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) {
      showErrorSnackBar(context, 'Lien de pièce jointe invalide.');
      return;
    }

    if (kIsWeb) {
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened && mounted) {
        showErrorSnackBar(context, 'Impossible d’ouvrir cette pièce jointe.');
      }
      return;
    }

    final localPath = await _downloadAttachmentToTempFile(attachment, uri: uri);
    if (localPath == null) {
      return;
    }

    final openedLocally = await openAttachmentFile(localPath);
    if (openedLocally) {
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showErrorSnackBar(context, 'Impossible d’ouvrir cette pièce jointe.');
    }
  }

  Future<void> _shareAttachment(MessageAttachment attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) {
      showErrorSnackBar(context, 'Lien de pièce jointe invalide.');
      return;
    }

    try {
      if (kIsWeb) {
        await Share.share(uri.toString(), subject: attachment.name);
        return;
      }

      final localPath = await _downloadAttachmentToTempFile(
        attachment,
        uri: uri,
      );
      if (localPath == null) {
        return;
      }

      await Share.shareXFiles(
        [
          XFile(
            localPath,
            mimeType: attachment.mimeType.trim().isEmpty
                ? null
                : attachment.mimeType,
            name: attachment.name,
          ),
        ],
        text: attachment.name,
        subject: attachment.name,
      );
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Impossible de partager cette pièce jointe.',
        );
      }
    }
  }

  Future<String?> _downloadAttachmentToTempFile(
    MessageAttachment attachment, {
    required Uri uri,
  }) async {
    try {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('http_${response.statusCode}');
      }
      return writeTempFile(
        response.bodyBytes,
        fileName: safeAttachmentName(attachment.name, 'piece_jointe.bin'),
      );
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Téléchargement impossible pour cette pièce jointe.',
        );
      }
      return null;
    }
  }

  Future<void> _deleteMessageById(String messageDocId) async {
    if (_deletingMessageIds.contains(messageDocId)) return;
    setState(() => _deletingMessageIds.add(messageDocId));
    try {
      await ConversationService.deleteMessage(
        conversationId: widget.conversationId,
        messageId: messageDocId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingMessageIds.remove(messageDocId));
      showErrorSnackBar(context, 'Suppression impossible : $error');
      return;
    }
    if (!mounted) return;
    setState(() => _deletingMessageIds.remove(messageDocId));
  }

  Widget _buildAttachmentPreview(
    MessageAttachment attachment, {
    bool canDelete = false,
    bool isDeleting = false,
    VoidCallback? onDelete,
  }) {
    Widget buildDeleteOverlay(Widget child) {
      if (!canDelete) return child;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDeleting ? Colors.grey : Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isDeleting
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
              ),
            ),
          ),
        ],
      );
    }

    if (attachment.type == 'image') {
      final fullUrl = attachment.url.isNotEmpty
          ? attachment.url
          : attachment.thumbnailUrl;
      return buildDeleteOverlay(
        GestureDetector(
          onTap: () => showGeneralDialog<void>(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Fermer',
            barrierColor: Colors.black,
            transitionDuration: Duration.zero,
            pageBuilder: (ctx, _, __) => Material(
              color: Colors.black,
              child: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: OfferNetworkImage(
                          url: fullUrl,
                          fit: BoxFit.contain,
                          errorChild: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                          loadingChild: const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      bottom: 18,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            'iliprestō',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              width: 240,
              height: 170,
              child: OfferNetworkImage(
                url: attachment.thumbnailUrl,
                fit: BoxFit.cover,
                loadingChild: Container(
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorChild: Container(
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (attachment.type == 'audio') {
      return buildDeleteOverlay(_VoiceNotePlayer(source: attachment.url));
    }

    return buildDeleteOverlay(
      SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: const Color(0xFFE5E7EB),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: const Color(0xFFE5E7EB),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => unawaited(_openAttachment(attachment)),
                customBorder: const CircleBorder(),
                child: Icon(
                  Icons.attach_file_rounded,
                  color: const Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentPreviews(
    List<MessageAttachment> attachments, {
    String? messageDocId,
    bool canDelete = false,
    bool isDeleting = false,
    VoidCallback? onDelete,
  }) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments) ...[
          _buildAttachmentPreview(
            attachment,
            canDelete: canDelete,
            isDeleting: isDeleting,
            onDelete: onDelete,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildOtherParticipantMessageAvatar() {
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFEAF2FF),
      foregroundColor: kPrestoBlue,
      foregroundImage: _otherParticipantPhotoUrl.isNotEmpty
          ? profileAvatarImageProvider(_otherParticipantPhotoUrl)
          : null,
      onForegroundImageError: _otherParticipantPhotoUrl.isNotEmpty
          ? (error, stackTrace) {
              debugPrint(
                '[ConversationThread] bubble avatar load failed '
                'participantId=$_otherParticipantId url=$_otherParticipantPhotoUrl '
                'error=$error',
              );
            }
          : null,
      child: _otherParticipantPhotoUrl.isEmpty
          ? Text(
              conversationInitial(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            )
          : null,
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMine,
    required String senderName,
    required DateTime? sentAt,
    String? messageDocId,
    List<MessageAttachment> attachments = const [],
    String? readReceipt,
    String? statusLabel,
    bool failed = false,
    bool groupedWithOlder = false,
    bool groupedWithNewer = false,
    bool isDeleted = false,
    bool isModerated = false,
    String moderatedPlaceholder = 'Message retiré par la modération',
    VoidCallback? onRetry,
    Future<void> Function()? onLongPress,
  }) {
    final labelParts = <String>[
      formatMessageTimestamp(sentAt),
      if (readReceipt != null) readReceipt,
      if (statusLabel != null) statusLabel,
    ];
    final hideAttachmentText = shouldHideAttachmentText(text, attachments);

    final canDeleteAttachments =
        isMine &&
        messageDocId != null &&
        attachments.isNotEmpty &&
        sentAt != null &&
        DateTime.now().difference(sentAt).inSeconds <= 180;
    final isDeletingMessage =
        messageDocId != null && _deletingMessageIds.contains(messageDocId);

    final bubbleContent = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isMine ? 320 : 288),
      child: Container(
        margin: EdgeInsets.only(
          top: groupedWithNewer ? 1 : 4,
          bottom: groupedWithOlder ? 1 : 4,
        ),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        decoration: BoxDecoration(
          color: failed
              ? const Color(0xFFFFE4E6)
              : isMine
              ? kThreadMineColor
              : kThreadOtherColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(!isMine && groupedWithNewer ? 8 : 18),
            topRight: Radius.circular(isMine && groupedWithNewer ? 8 : 18),
            bottomLeft: Radius.circular(
              !isMine && groupedWithOlder
                  ? 8
                  : isMine
                  ? 18
                  : 4,
            ),
            bottomRight: Radius.circular(
              isMine && groupedWithOlder
                  ? 8
                  : isMine
                  ? 4
                  : 18,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine && senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  senderName,
                  style: kPrestoMetaTextStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            if (isDeleted)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    size: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Message supprimé',
                    style: kPrestoBodyTextStyle.copyWith(
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            else if (isModerated)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      moderatedPlaceholder,
                      style: kPrestoBodyTextStyle.copyWith(
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              _buildAttachmentPreviews(
                attachments,
                messageDocId: messageDocId,
                canDelete: canDeleteAttachments,
                isDeleting: isDeletingMessage,
                onDelete: canDeleteAttachments
                    ? () => _deleteMessageById(messageDocId)
                    : null,
              ),
              if (text.isNotEmpty && !hideAttachmentText)
                Text(
                  text,
                  style: kPrestoBodyTextStyle.copyWith(
                    color: const Color(0xFF111827),
                    height: 1.3,
                    fontSize: 15,
                  ),
                ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    labelParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kPrestoMetaTextStyle.copyWith(
                      fontSize: 11,
                      color: failed
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
                if (failed && onRetry != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onRetry,
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 15,
                        color: Color(0xFFFF0000),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: isMine
            ? bubbleContent
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildOtherParticipantMessageAvatar(),
                  const SizedBox(width: 4),
                  Flexible(child: bubbleContent),
                ],
              ),
      ),
    );
  }

  Widget _buildMessagesAccessGate() {
    final isPreparing = _isPreparingMessageStream;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPreparing)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
              )
            else
              const Icon(
                Icons.lock_clock_rounded,
                color: Color(0xFF6B7280),
                size: 42,
              ),
            const SizedBox(height: 14),
            Text(
              isPreparing
                  ? 'Preparation securisee de la messagerie…'
                  : 'La messagerie est temporairement indisponible. Verifiez App Check, votre connexion puis reessayez.',
              textAlign: TextAlign.center,
              style: kPrestoBodyTextStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
            if (!isPreparing) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _warmMessagingAccess,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kThreadBackground,
      appBar: AppBar(
        systemOverlayStyle: kConversationThreadStatusBarStyle,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: _buildThreadAppBarTitle(),
        actions: [
          PopupMenuButton<_ConversationThreadAction>(
            onSelected: _handleConversationAction,
            itemBuilder: (context) => [
              PopupMenuItem<_ConversationThreadAction>(
                value: archivedForCurrentUser
                    ? _ConversationThreadAction.unarchive
                    : _ConversationThreadAction.archive,
                child: Text(archivedForCurrentUser ? 'Restaurer' : 'Archiver'),
              ),
              if (blockedForCurrentUser)
                const PopupMenuItem<_ConversationThreadAction>(
                  value: _ConversationThreadAction.unblock,
                  child: Text('Debloquer'),
                )
              else if (blockedByAnotherParticipant && adminViewerState)
                const PopupMenuItem<_ConversationThreadAction>(
                  value: _ConversationThreadAction.adminUnblock,
                  child: Text('Debloquer en admin'),
                )
              else if (blockedByAnotherParticipant)
                const PopupMenuItem<_ConversationThreadAction>(
                  enabled: false,
                  child: Text('Bloquee par l autre utilisateur'),
                )
              else
                const PopupMenuItem<_ConversationThreadAction>(
                  value: _ConversationThreadAction.block,
                  child: Text('Bloquer'),
                ),
              const PopupMenuItem<_ConversationThreadAction>(
                value: _ConversationThreadAction.delete,
                child: Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildWatermark(),
          Column(
            children: [
              _buildOfferContextBanner(),
              buildStateBanner(),
              buildSafetyReminderBanner(),
              buildTypingIndicator(),
              Expanded(
                child: _isPreparingMessageStream || _messageStream == null
                    ? _buildMessagesAccessGate()
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _messageStream!,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  kPrestoOrange,
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            _debugMessagingAccess(
                              'messages-subcollection-stream-error',
                              error: snapshot.error,
                              firestorePath:
                                  'conversations/${widget.conversationId}/messages',
                            );
                            if (messagingErrorCode(snapshot.error) ==
                                'permission-denied') {
                              _retryMessageStreamAccessAfterDenied(
                                snapshot.error,
                              );
                            }
                            final message = messageStreamErrorMessage(
                              snapshot.error,
                            );
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      message,
                                      textAlign: TextAlign.center,
                                      style: kPrestoBodyTextStyle.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF4B5563),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: _warmMessagingAccess,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Réessayer'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final liveDocs = snapshot.data?.docs ?? const [];
                          _handleLiveMessageDocs(liveDocs);
                          applyInitialDraftIfNeeded(liveDocs.isNotEmpty);
                          final docs = _mergeMessageDocs(liveDocs);
                          final visibleItemCount =
                              docs.length + _optimisticMessages.length;
                          final canLoadMore =
                              docs.isNotEmpty &&
                              (_hasAttemptedOlderPagination
                                  ? _hasMoreMessages
                                  : liveDocs.length >= _messagePageSize);

                          if (visibleItemCount == 0) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Aucun message pour le moment.\nVous pouvez lancer la conversation.',
                                  textAlign: TextAlign.center,
                                  style: kPrestoBodyTextStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            );
                          }

                          return Stack(
                            children: [
                              NotificationListener<ScrollNotification>(
                                onNotification: (_) {
                                  if (_showNewMessagesButton &&
                                      _isNearLatestMessage()) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(
                                            () =>
                                                _showNewMessagesButton = false,
                                          );
                                        });
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    8,
                                    6,
                                    16,
                                  ),
                                  itemCount: visibleItemCount + 1,
                                  itemBuilder: (context, index) {
                                    if (index == visibleItemCount) {
                                      // Dernier item (visuellement en haut) : bouton charger plus
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (canLoadMore)
                                            TextButton.icon(
                                              onPressed: _isLoadingMoreMessages
                                                  ? null
                                                  : () => _loadMoreMessages(
                                                      liveDocs,
                                                    ),
                                              icon: _isLoadingMoreMessages
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.history_rounded,
                                                      size: 16,
                                                    ),
                                              label: Text(
                                                _isLoadingMoreMessages
                                                    ? 'Chargement...'
                                                    : 'Charger les messages plus anciens',
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFF6B7280,
                                                ),
                                                textStyle: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    }

                                    if (index < _optimisticMessages.length) {
                                      final optimisticMessage =
                                          _optimisticMessages[index];
                                      return _buildMessageBubble(
                                        text: optimisticMessage.text,
                                        isMine: true,
                                        senderName:
                                            optimisticMessage.senderName,
                                        sentAt: optimisticMessage.sentAt,
                                        attachments:
                                            optimisticMessage.attachments,
                                        statusLabel:
                                            optimisticMessage.status ==
                                                OptimisticMessageStatus.failed
                                            ? 'Non envoyé'
                                            : 'Envoi...',
                                        failed:
                                            optimisticMessage.status ==
                                            OptimisticMessageStatus.failed,
                                        onRetry:
                                            optimisticMessage.status ==
                                                OptimisticMessageStatus.failed
                                            ? () => _retryOptimisticMessage(
                                                optimisticMessage,
                                              )
                                            : null,
                                      );
                                    }

                                    final docIndex =
                                        index - _optimisticMessages.length;
                                    final data = docs[docIndex].data();
                                    final text =
                                        ((data['text'] ?? data['body']) ?? '')
                                            .toString();
                                    final senderId =
                                        ((data['senderId'] ??
                                                    data['sender_id']) ??
                                                '')
                                            .toString();
                                    final senderName =
                                        ((data['senderName'] ??
                                                    data['sender_name']) ??
                                                '')
                                            .toString();
                                    final sentAt = parseFirestoreDateTime(
                                      (data['createdAt'] ?? data['created_at']),
                                    );
                                    final olderMessageDate =
                                        docIndex + 1 < docs.length
                                        ? parseFirestoreDateTime(
                                            (docs[docIndex + 1]
                                                    .data()['createdAt'] ??
                                                docs[docIndex + 1]
                                                    .data()['created_at']),
                                          )
                                        : null;
                                    final showDateChip =
                                        sentAt != null &&
                                        (olderMessageDate == null ||
                                            !isSameCalendarDay(
                                              sentAt,
                                              olderMessageDate,
                                            ));
                                    final isMine =
                                        senderId == widget.currentUserId;
                                    final readReceipt = isMine
                                        ? readReceiptLabel(sentAt)
                                        : null;
                                    final messageDocId = docs[docIndex].id;
                                    final attachments =
                                        MessageAttachment.fromList(
                                          data['attachments'],
                                        );
                                    final moderation =
                                        MessageModeration.fromMap(
                                          data['moderation'],
                                        );
                                    final isDeleted = data['deletedAt'] != null;
                                    final isDeletingMessage =
                                        _deletingMessageIds.contains(
                                          messageDocId,
                                        );
                                    final showAsDeleted =
                                        isDeleted || isDeletingMessage;
                                    final showAsModerated =
                                        moderation.shouldHideContent &&
                                        !showAsDeleted;

                                    final newerSenderId = docIndex > 0
                                        ? ((docs[docIndex - 1]
                                                          .data()['senderId'] ??
                                                      docs[docIndex - 1]
                                                          .data()['sender_id']) ??
                                                  '')
                                              .toString()
                                        : '';
                                    final olderSenderId =
                                        docIndex + 1 < docs.length
                                        ? ((docs[docIndex + 1]
                                                          .data()['senderId'] ??
                                                      docs[docIndex + 1]
                                                          .data()['sender_id']) ??
                                                  '')
                                              .toString()
                                        : '';
                                    final groupedWithNewer =
                                        newerSenderId == senderId &&
                                        newerSenderId.isNotEmpty &&
                                        !showDateChip;
                                    final groupedWithOlder =
                                        olderSenderId == senderId &&
                                        olderSenderId.isNotEmpty &&
                                        !showDateChip;

                                    final messageBubble = _buildMessageBubble(
                                      text: text,
                                      isMine: isMine,
                                      senderName: senderName,
                                      sentAt: sentAt,
                                      messageDocId: messageDocId,
                                      attachments: attachments,
                                      readReceipt: readReceipt,
                                      statusLabel: isMine && readReceipt == null
                                          ? 'Envoyé'
                                          : null,
                                      groupedWithNewer: groupedWithNewer,
                                      groupedWithOlder: groupedWithOlder,
                                      isDeleted: showAsDeleted,
                                      isModerated: showAsModerated,
                                      moderatedPlaceholder:
                                          moderation.placeholderText,
                                      onLongPress: isMine && !showAsDeleted
                                          ? () async {
                                              final scaffoldMessenger =
                                                  ScaffoldMessenger.of(context);
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) {
                                                  final overlayTheme =
                                                      ctx.prestoOverlayTheme;
                                                  return AlertDialog(
                                                    icon: const Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: Color(0xFFFF6600),
                                                      size: 38,
                                                    ),
                                                    backgroundColor:
                                                        overlayTheme
                                                            .surfaceColor,
                                                    surfaceTintColor:
                                                        overlayTheme
                                                            .surfaceTintColor,
                                                    shape: overlayTheme
                                                        .dialogShape,
                                                    title: const Text(
                                                      'Supprimer ce message',
                                                    ),
                                                    content: const Text(
                                                      'Le contenu sera remplacé par « Message supprimé ». La bulle reste visible avec la date et l\'heure.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'Annuler',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop(true),
                                                        style:
                                                            TextButton.styleFrom(
                                                              foregroundColor:
                                                                  Colors.red,
                                                            ),
                                                        child: const Text(
                                                          'Supprimer',
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                              if (confirmed != true ||
                                                  !mounted) {
                                                return;
                                              }
                                              setState(
                                                () => _deletingMessageIds.add(
                                                  messageDocId,
                                                ),
                                              );
                                              try {
                                                await ConversationService.deleteMessage(
                                                  conversationId:
                                                      widget.conversationId,
                                                  messageId: messageDocId,
                                                );
                                                if (!mounted) return;
                                                scaffoldMessenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Message supprimé.',
                                                    ),
                                                  ),
                                                );
                                              } catch (error) {
                                                if (!mounted) return;
                                                setState(
                                                  () => _deletingMessageIds
                                                      .remove(messageDocId),
                                                );
                                                scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Impossible de supprimer ce message : $error',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          : null,
                                    );

                                    if (!showDateChip) {
                                      return messageBubble;
                                    }

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        buildThreadDateChip(sentAt),
                                        messageBubble,
                                      ],
                                    );
                                  },
                                ),
                              ),
                              if (_showNewMessagesButton)
                                Positioned(
                                  right: 18,
                                  bottom: 18,
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        _scrollToLatestMessage(force: true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: kPrestoBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                    ),
                                    label: const Text('Nouveaux messages'),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEmojiStrip(),
                      _buildMessagingSubscriptionBadge(),
                      if (_isUploadingAttachment) ...[
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Envoi de la pièce jointe...',
                              style: kPrestoMetaTextStyle.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Tooltip(
                            message: 'Ajouter une pièce jointe',
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Material(
                                color:
                                    (conversationBlocked ||
                                        _isUploadingAttachment ||
                                        _isSending)
                                    ? const Color(0xFFF3F4F6)
                                    : Colors.white,
                                shape: const CircleBorder(
                                  side: BorderSide(
                                    color: Color(0xFFD1D5DB),
                                    width: 1.2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap:
                                      (conversationBlocked ||
                                          _isUploadingAttachment ||
                                          _isSending)
                                      ? null
                                      : _showAttachmentSheet,
                                  child: Center(
                                    child: Icon(
                                      Icons.attach_file_rounded,
                                      color:
                                          (conversationBlocked ||
                                              _isUploadingAttachment ||
                                              _isSending)
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF6B7280),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: messageController,
                                textInputAction: TextInputAction.send,
                                enabled: !conversationBlocked,
                                minLines: 1,
                                maxLines: 4,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: InputDecoration(
                                  hintText: conversationBlocked
                                      ? 'Envoi indisponible : conversation bloquee'
                                      : 'Votre message...',
                                  prefixIcon: IconButton(
                                    tooltip: 'Emoji',
                                    onPressed: conversationBlocked
                                        ? null
                                        : () => setState(
                                            () => _showEmojiStrip =
                                                !_showEmojiStrip,
                                          ),
                                    icon: Icon(
                                      _showEmojiStrip
                                          ? Icons.keyboard_rounded
                                          : Icons.emoji_emotions_outlined,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: FilledButton(
                              onPressed:
                                  (_isSending ||
                                      _isUploadingAttachment ||
                                      conversationBlocked)
                                  ? null
                                  : _hasDraftText
                                  ? _sendMessage
                                  : () => unawaited(_showVoiceRecordingSheet()),
                              style: FilledButton.styleFrom(
                                backgroundColor: kWhatsappGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFE5E7EB,
                                ),
                                disabledForegroundColor: const Color(
                                  0xFF9CA3AF,
                                ),
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(44, 44),
                                fixedSize: const Size(44, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: (_isSending || _isUploadingAttachment)
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _hasDraftText
                                          ? Icons.send_rounded
                                          : Icons.mic_none_rounded,
                                      size: 22,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum OptimisticMessageStatus { sending, failed }

class OptimisticMessage {
  final String id;
  final String text;
  final List<MessageAttachment> attachments;
  final DateTime sentAt;
  final String senderName;
  final OptimisticMessageStatus status;

  const OptimisticMessage({
    required this.id,
    required this.text,
    this.attachments = const [],
    required this.sentAt,
    required this.senderName,
    required this.status,
  });

  OptimisticMessage copyWith({OptimisticMessageStatus? status}) {
    return OptimisticMessage(
      id: id,
      text: text,
      attachments: attachments,
      sentAt: sentAt,
      senderName: senderName,
      status: status ?? this.status,
    );
  }
}

class MessageModeration {
  final String status;
  final String visibility;

  const MessageModeration({required this.status, required this.visibility});

  static const _none = MessageModeration(status: '', visibility: 'visible');

  static MessageModeration fromMap(Object? value) {
    if (value is! Map) return _none;
    return MessageModeration(
      status: (value['status'] ?? '').toString().trim().toLowerCase(),
      visibility: (value['visibility'] ?? 'visible')
          .toString()
          .trim()
          .toLowerCase(),
    );
  }

  bool get shouldHideContent {
    return status == 'rejected' ||
        status == 'manual_review' ||
        (status == 'pending' && visibility == 'hidden');
  }

  String get placeholderText {
    switch (status) {
      case 'rejected':
        return 'Message retiré par la modération';
      case 'manual_review':
        return 'Message masqué en attente de vérification';
      case 'pending':
        return 'Message en cours de vérification';
      default:
        return 'Message modéré';
    }
  }
}

class MessageAttachment {
  final String type;
  final String name;
  final String url;
  final String thumbnailUrl;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;

  const MessageAttachment({
    required this.type,
    required this.name,
    required this.url,
    String? thumbnailUrl,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
  }) : thumbnailUrl = thumbnailUrl ?? url;

  static List<MessageAttachment> fromList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => MessageAttachment.fromMap(entry))
        .whereType<MessageAttachment>()
        .toList(growable: false);
  }

  static MessageAttachment? fromMap(Map<dynamic, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final name = (data['name'] ?? '').toString();
    final url = (data['url'] ?? data['downloadUrl'] ?? '').toString();
    final thumbnailUrl =
        (data['thumbnailUrl'] ?? data['url'] ?? data['downloadUrl'] ?? '')
            .toString();
    final storagePath = (data['storagePath'] ?? '').toString();
    final mimeType = (data['mimeType'] ?? '').toString();
    final sizeBytes = (data['sizeBytes'] is num)
        ? (data['sizeBytes'] as num).round()
        : int.tryParse((data['sizeBytes'] ?? '').toString()) ?? 0;
    if ((type != 'image' && type != 'document' && type != 'audio') ||
        url.trim().isEmpty) {
      return null;
    }
    return MessageAttachment(
      type: type,
      name: name.trim().isEmpty
          ? (type == 'image'
                ? 'Photo'
                : type == 'audio'
                ? 'Note vocale'
                : 'Document')
          : name,
      url: url,
      thumbnailUrl: thumbnailUrl.trim().isEmpty ? url : thumbnailUrl,
      storagePath: storagePath,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }

  ConversationAttachmentInput toInput() {
    return ConversationAttachmentInput(
      type: type,
      name: name,
      url: url,
      storagePath: storagePath,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
    );
  }
}

class _AttachmentActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AttachmentActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: kPrestoBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: kPrestoBodyTextStyle.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: kPrestoMetaTextStyle.copyWith(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class OfferPreview {
  final String id;
  final String title;
  final String priceLabel;
  final String imageUrl;

  const OfferPreview({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.imageUrl,
  });

  factory OfferPreview.fromMap(String id, Map<String, dynamic> data) {
    final title = _firstText(data, const [
      'title',
      'listingTitle',
      'offerTitle',
    ]);
    final priceValue = _firstValue(data, const [
      'price',
      'budget',
      'amount',
      'salary',
      'dailyRate',
    ]);
    final priceLabel = _formatOfferPrice(priceValue);
    final imageUrl = _firstImageUrl(data);

    return OfferPreview(
      id: id,
      title: title,
      priceLabel: priceLabel,
      imageUrl: imageUrl,
    );
  }

  static Object? _firstValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  static String _firstText(Map<String, dynamic> data, List<String> keys) {
    final value = _firstValue(data, keys);
    return value?.toString().trim() ?? '';
  }

  static String _firstImageUrl(Map<String, dynamic> data) {
    final direct = _firstText(data, const [
      'thumbnailUrl',
      'imageUrl',
      'photoUrl',
    ]);
    if (direct.isNotEmpty) return direct;

    final imageUrls = data['imageUrls'];
    if (imageUrls is Iterable) {
      for (final entry in imageUrls) {
        final value = entry?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }

    final media = data['media'];
    if (media is Iterable) {
      for (final entry in media) {
        if (entry is! Map) continue;
        final value = (entry['url'] ?? entry['downloadUrl'] ?? '')
            .toString()
            .trim();
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  static String _formatOfferPrice(Object? value) {
    if (value == null) return '';
    if (value is num) {
      if (value <= 0) return '';
      final rounded = value == value.roundToDouble()
          ? value.toInt().toString()
          : value
                .toStringAsFixed(2)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), '');
      return '$rounded €';
    }
    final text = value.toString().trim();
    if (text.isEmpty || text == '0') return '';
    return text.contains('€') ? text : '$text €';
  }
}

enum _ConversationThreadAction {
  archive,
  unarchive,
  block,
  unblock,
  adminUnblock,
  delete,
}

class _ConversationBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _ConversationBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: kPrestoMetaTextStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationPatternBackground extends StatelessWidget {
  const _ConversationPatternBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          child: CustomPaint(
            painter: _ConversationPatternPainter(),
            size: Size.infinite,
          ),
        ),
        Positioned(
          bottom: -60,
          right: -40,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.08,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_circle,
                  size: 280,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFEFE),
    );

    final dotPaint = Paint()
      ..color = const Color(0xFFEAF2FF).withValues(alpha: 0.55);
    const spacing = 34.0;
    for (var y = 18.0; y < size.height; y += spacing) {
      for (var x = 18.0; x < size.width; x += spacing) {
        final offset = ((y / spacing).floor().isEven) ? 0.0 : spacing / 2;
        canvas.drawCircle(Offset(x + offset, y), 1.1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VoiceRecordingSheet extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _VoiceRecordingSheet({required this.onCancel, required this.onSend});

  @override
  State<_VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<_VoiceRecordingSheet>
    with SingleTickerProviderStateMixin {
  Timer? _displayTimer;
  Duration _elapsed = Duration.zero;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _displayTimer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _pulseController,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _fmt(_elapsed),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Enregistrement en cours…',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onSend,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Envoyer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kWhatsappGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _VoiceNotePreviewAction { cancel, rerecord, send }

class _ConversationAttachmentGateDecision {
  final String title;
  final String message;
  final String source;
  final bool stripeEnabled;

  const _ConversationAttachmentGateDecision({
    required this.title,
    required this.message,
    required this.source,
    required this.stripeEnabled,
  });
}

class _PendingVoiceNote {
  final Duration duration;
  final Uint8List? bytes;
  final String? filePath;
  final String previewSource;
  final bool previewIsLocalFile;
  final String mimeType;
  final String extension;
  final bool usesGeneratedPreviewSource;

  const _PendingVoiceNote({
    required this.duration,
    this.bytes,
    this.filePath,
    required this.previewSource,
    required this.previewIsLocalFile,
    required this.mimeType,
    required this.extension,
    this.usesGeneratedPreviewSource = false,
  });
}

class _VoiceNotePreviewSheet extends StatelessWidget {
  final _PendingVoiceNote preview;
  final VoidCallback onCancel;
  final VoidCallback onRerecord;
  final VoidCallback onSend;

  const _VoiceNotePreviewSheet({
    required this.preview,
    required this.onCancel,
    required this.onRerecord,
    required this.onSend,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final compactOutlinedStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      minimumSize: const Size(0, 44),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
    final compactFilledStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      minimumSize: const Size(0, 44),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      backgroundColor: kWhatsappGreen,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Relire la note vocale',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Durée ${_fmt(preview.duration)}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: _VoiceNotePlayer(
                source: preview.previewSource,
                isLocalFile: preview.previewIsLocalFile,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Annuler', maxLines: 1, softWrap: false),
                    style: compactOutlinedStyle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRerecord,
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: const Text('Refaire', maxLines: 1, softWrap: false),
                    style: compactOutlinedStyle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Envoyer', maxLines: 1, softWrap: false),
                    style: compactFilledStyle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceNotePlayer extends StatefulWidget {
  final String source;
  final bool isLocalFile;

  const _VoiceNotePlayer({required this.source, this.isLocalFile = false});

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  bool _isLoading = false;
  bool _sourceLoaded = false;

  bool get _isPlaying => _state == PlayerState.playing;
  bool get _isPaused => _state == PlayerState.paused;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _state = s;
        _isLoading = false;
      });
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _total = d);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _state = PlayerState.stopped;
        _position = Duration.zero;
      });
    });
    unawaited(_prepareSource());
  }

  @override
  void didUpdateWidget(covariant _VoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.isLocalFile != widget.isLocalFile) {
      unawaited(_resetForNewUrl());
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _prepareSource() async {
    final source = widget.source.trim();
    if (source.isEmpty) return;
    try {
      await _player.setSource(
        widget.isLocalFile ? DeviceFileSource(source) : UrlSource(source),
      );
      final duration = await _player.getDuration();
      if (!mounted) return;
      setState(() {
        _sourceLoaded = true;
        if (duration != null && duration > Duration.zero) {
          _total = duration;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sourceLoaded = false);
    }
  }

  Future<void> _resetForNewUrl() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _state = PlayerState.stopped;
      _position = Duration.zero;
      _total = Duration.zero;
      _isLoading = false;
      _sourceLoaded = false;
    });
    await _prepareSource();
  }

  Future<void> _toggle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (_isPlaying) {
        await _player.pause();
      } else if (_isPaused) {
        await _player.resume();
      } else {
        if (!_sourceLoaded) {
          await _prepareSource();
        }
        if (_sourceLoaded) {
          if (_position > Duration.zero &&
              _total > Duration.zero &&
              _position >= _total) {
            await _player.seek(Duration.zero);
          }
          await _player.resume();
        } else {
          final source = widget.source.trim();
          await _player.play(
            widget.isLocalFile ? DeviceFileSource(source) : UrlSource(source),
          );
          final duration = await _player.getDuration();
          if (!mounted) return;
          if (duration != null && duration > Duration.zero) {
            setState(() => _total = duration);
          }
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = PlayerState.stopped;
        _isLoading = false;
        _sourceLoaded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240, minWidth: 180),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton.filled(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onPressed: _toggle,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: const Color(0x33000000),
                ),
                const SizedBox(height: 4),
                Text(
                  _total > Duration.zero
                      ? '${_fmt(_position)} / ${_fmt(_total)}'
                      : _fmt(_position),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
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

String formatMessageTimestamp(DateTime? date) {
  if (date == null) return 'Envoi...';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String formatThreadDateLabel(DateTime? date) {
  if (date == null) return '--/--/----';

  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final value = DateTime(local.year, local.month, local.day);
  final diff = today.difference(value).inDays;

  if (diff == 0) return 'Aujourd’hui';
  if (diff == 1) return 'Hier';
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String formatPresenceSeenAt(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  return 'le ${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}

bool isDeletedUserMap(Map<String, dynamic>? data) {
  return DeletedUserProfile.isDeletedMap(data);
}

String deletedAwareDisplayName(
  Map<String, dynamic>? data,
  String? fallbackName,
) {
  return DeletedUserProfile.displayName(
    isDeleted: isDeletedUserMap(data),
    fallbackName: fallbackName,
  );
}

Widget deletedAwareAvatar({
  required Map<String, dynamic>? data,
  required Widget fallback,
  double radius = 22,
}) {
  if (isDeletedUserMap(data)) {
    return DeletedUserAvatar(radius: radius);
  }

  return fallback;
}
