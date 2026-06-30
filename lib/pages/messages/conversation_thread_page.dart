import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/presto_overlay_theme.dart';
import '../../constants.dart';
import '../../services/conversation_service.dart';
import '../../services/conversation_state.dart';
import '../../services/admin_access_resolver.dart';
import '../../services/admin_web_debug_store.dart';
import '../../services/conversation_participants.dart';
import '../../services/firestore_date_parser.dart';
import '../../services/user_profile_bootstrap_service.dart';
import '../../utils/friendly_snackbar.dart';
import '../../widgets/offer_network_image.dart';
import 'package:presto_app/services/auth_guard.dart';
import 'package:presto_app/utils/profile_avatar_resolver.dart';
import '../../utils/recording_path_web.dart'
    if (dart.library.io) '../../utils/recording_path_io.dart';
import '../../utils/temp_file_helper_web.dart'
    if (dart.library.io) '../../utils/temp_file_helper_io.dart';
import 'package:presto_app/widgets/deleted_user_profile.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);
const kThreadMineColor = Color(0xFFD9FDD3);
const kThreadOtherColor = Colors.white;
const kThreadBackground = Color(0xFFFFFEFE);
const kWhatsappGreen = Color(0xFF25D366);
const kConversationThreadStatusBarStyle = SystemUiOverlayStyle(
  statusBarColor: kPrestoBlue,
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

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_OptimisticMessage> _optimisticMessages = <_OptimisticMessage>[];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _conversationSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _presenceSubscription;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _olderMessageDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  Timer? _typingStopTimer;
  QueryDocumentSnapshot<Map<String, dynamic>>? _paginationAnchorDoc;
  Future<_OfferPreview?>? _offerPreviewFuture;
  String? _offerPreviewFutureId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messageStream;
  bool _isSending = false;
  bool _hasDraftText = false;
  bool _isMarkingRead = false;
  bool _hasAttemptedOlderPagination = false;
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;
  List<String> _participants = const [];
  Map<String, String> _participantNames = const {};
  Map<String, dynamic> _lastReadAt = const {};
  bool _metaLoaded = false;
  bool _didApplyInitialDraft = false;
  bool _showSafetyReminder = true;
  bool _isOfferCardExpanded = true;
  bool _showEmojiStrip = false;
  bool _isOtherTyping = false;
  bool _showNewMessagesButton = false;
  bool _isUploadingAttachment = false;
  bool _canLookupOtherParticipantProfile = false;
  bool _isPreparingMessageStream = true;
  bool _isAdminViewer = false;
  String? _newestLiveMessageId;
  bool _isBlocked = false;
  bool _isBlockedForCurrentUser = false;
  bool _isBlockedByAnotherParticipant = false;
  bool _isArchivedForCurrentUser = false;
  bool _hasHandledConversationRemoval = false;
  int _messageStreamRetryCount = 0;
  String _offerId = '';
  String _conversationOfferTitle = '';
  String _otherParticipantId = '';
  String _otherParticipantName = '';
  String _otherParticipantPhotoSource = '';
  String _otherParticipantPhotoUrl = '';
  String _otherPresenceStatus = '';
  DateTime? _otherLastSeenAt;
  bool _isRecording = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  AudioRecorder? _voiceRecorder;
  String? _currentRecordingPath;

  Object? _conversationValue(Map<String, dynamic> data, List<String> keys) {
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
    final detail = 'currentUser.uid=$currentUid '
        'widget.currentUserId=${widget.currentUserId} '
        'conversationId=${widget.conversationId} '
        'path=${firestorePath ?? 'conversations/${widget.conversationId}'} '
        'participants=${participants ?? _participants} '
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
        level: reason.contains('retry') ||
                reason.contains('missing') ||
                reason.contains('not-found')
            ? 'warn'
            : 'info',
        detail: detail,
      );
    }
    if (!kDebugMode) return;
    debugPrint(
      '[ConversationThread][access] reason=$reason $detail',
    );
  }

  String _messagingErrorCode(Object? error) {
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

  String _messageStreamErrorMessage(Object? error) {
    final code = _messagingErrorCode(error);
    final isCurrentUserParticipant =
        _participants.contains(widget.currentUserId);
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

  String _sendMessageErrorMessage(Object? error) {
    final code = _messagingErrorCode(error);
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
    _controller.addListener(_handleDraftChanged);
    unawaited(_warmMessagingAccess());
    unawaited(_resolveParticipantProfileLookupAccess());
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _presenceSubscription?.cancel();
    _typingStopTimer?.cancel();
    _recordingTimer?.cancel();
    _voiceRecorder?.dispose();
    unawaited(_publishTyping(false));
    _controller.removeListener(_handleDraftChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleDraftChanged() {
    final nextHasDraftText = _controller.text.trim().isNotEmpty;
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
          _isAdminViewer == isAdminViewer) {
        if (canLookup && _otherParticipantId.trim().isNotEmpty) {
          _bindPresenceListener(_otherParticipantId);
        }
        return;
      }

      setState(() {
        _canLookupOtherParticipantProfile = canLookup;
        _isAdminViewer = isAdminViewer;
        if (!canLookup) {
          _otherPresenceStatus = '';
          _otherLastSeenAt = null;
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

  Widget _buildThreadDateChip(DateTime? date) {
    final label = _formatThreadDateLabel(date);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF6E7BE),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: kPrestoMetaTextStyle.copyWith(
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameCalendarDay(DateTime? left, DateTime? right) {
    if (left == null || right == null) return false;
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _conversationInitial() {
    final raw = _headerDisplayName.trim();
    if (raw.isEmpty) return '?';
    return raw.characters.first.toUpperCase();
  }

  String get _headerOfferTitle {
    final normalized = _conversationOfferTitle.trim().isNotEmpty
        ? _conversationOfferTitle.trim()
        : widget.offerTitle.trim();
    return normalized.isEmpty ? 'Annonce' : normalized;
  }

  String get _headerDisplayName {
    final normalized = _otherParticipantName.trim();
    return normalized.isEmpty ? _headerOfferTitle : normalized;
  }

  String get _headerSubtitle {
    if (_isOtherTyping) return '$_headerDisplayName écrit…';
    final status = _otherPresenceStatus.trim().toLowerCase();
    if (status == 'online' && _isRecentlySeen(_otherLastSeenAt)) {
      return 'en ligne';
    }
    if (_otherLastSeenAt != null) {
      return 'vu ${_formatPresenceSeenAt(_otherLastSeenAt!)}';
    }
    return _headerOfferTitle;
  }

  bool _isRecentlySeen(DateTime? value) {
    if (value == null) return true;
    return DateTime.now().difference(value.toLocal()) <
        const Duration(minutes: 4);
  }

  String _readText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Map<String, String> _readStringMap(
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

  String _firstProfilePhotoValue(Map<String, dynamic> data) {
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

  String _firstStoredProfilePhotoPath(Map<String, dynamic> data) {
    return (data['profilePhotoPath'] ?? '').toString().trim();
  }

  bool _isResolvableStorageProfilePhoto(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('gs://') || trimmed.startsWith('profilePhotos/');
  }

  bool _isNetworkProfilePhoto(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('https://') || trimmed.startsWith('http://');
  }

  Future<void> _resolveOtherParticipantPhoto({
    required String participantId,
    required String storedPath,
    required String currentPhotoValue,
  }) async {
    final source =
        storedPath.isNotEmpty ? storedPath : currentPhotoValue.trim();
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
      final downloadUrl =
          await ref.getDownloadURL().timeout(const Duration(seconds: 12));
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
    final userDocument =
        FirebaseFirestore.instance.collection('users').doc(participantId);
    _presenceSubscription = userDocument.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      final rawPhotoValue = _firstProfilePhotoValue(data);
      final storedPath = _firstStoredProfilePhotoPath(data);
      final needsStorageResolution =
          (rawPhotoValue.isEmpty && storedPath.isNotEmpty) ||
              _isResolvableStorageProfilePhoto(rawPhotoValue);
      final networkPhotoUrl =
          _isNetworkProfilePhoto(rawPhotoValue) ? rawPhotoValue.trim() : '';
      if (!mounted) return;
      setState(() {
        _otherPresenceStatus =
            (data['status'] ?? '').toString().trim().toLowerCase();
        _otherLastSeenAt = parseFirestoreDateTime(data['lastSeenAt']);
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
    }, onError: (Object error, StackTrace stackTrace) {
      _debugMessagingAccess(
        'presence-listen-error',
        error: error,
        firestorePath: 'users/$participantId',
      );
    });
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
        'typingUpdatedAt.${widget.currentUserId}': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('[ConversationThread] typing update skipped: $error');
    }
  }

  Future<_OfferPreview?> _offerPreviewFor(String offerId) {
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

  Future<_OfferPreview?> _loadOfferPreview(String offerId) async {
    for (final collectionName in const ['listings', 'offers']) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(offerId)
            .get();
        final data = snapshot.data();
        if (data != null) {
          return _OfferPreview.fromMap(offerId, data);
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
    Navigator.of(context)
        .pushNamed('/offers/${Uri.encodeComponent(normalizedOfferId)}');
  }

  Widget _buildThreadAppBarTitle() {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          foregroundColor: Colors.white,
          foregroundImage: _otherParticipantPhotoUrl.isNotEmpty
              ? profileAvatarImageProvider(_otherParticipantPhotoUrl)
              : null,
          onForegroundImageError: (error, stackTrace) {
            debugPrint(
              '[ConversationThread] header avatar load failed '
              'participantId=$_otherParticipantId url=$_otherParticipantPhotoUrl '
              'error=$error',
            );
          },
          child: _otherParticipantPhotoUrl.isEmpty
              ? Text(
                  _conversationInitial(),
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
                _headerDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kPrestoAppBarTitleStyle,
              ),
              const SizedBox(height: 1),
              Text(
                _metaLoaded ? _headerSubtitle : 'Chargement...',
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
    );
  }

  Widget _buildOfferContextBanner() {
    final normalizedOfferId = _offerId.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: FutureBuilder<_OfferPreview?>(
        future: _offerPreviewFor(normalizedOfferId),
        builder: (context, snapshot) {
          final preview = snapshot.data ??
              _OfferPreview(
                id: normalizedOfferId,
                title: _headerOfferTitle,
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
                        : Image.network(
                            preview.imageUrl,
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
                            ? _headerOfferTitle
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
    _conversationSubscription =
        conversationDocument.snapshots().listen((snapshot) {
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
      final isCurrentUserParticipant =
          participants.contains(widget.currentUserId);
      _debugMessagingAccess(
        isCurrentUserParticipant
            ? 'conversation-document-loaded-participant-ok'
            : 'conversation-document-loaded-current-user-missing',
        participants: participants,
        firestorePath: 'conversations/${widget.conversationId}',
      );
      final participantNames = _readStringMap(
        data,
        const ['participantNames', 'participant_names'],
      );
      final otherParticipantId = participants.firstWhere(
        (participantId) => participantId != widget.currentUserId,
        orElse: () => '',
      );
      final otherParticipantName =
          (participantNames[otherParticipantId] ?? '').trim().isNotEmpty
              ? participantNames[otherParticipantId]!.trim()
              : _readText(
                  data,
                  const ['otherUserName', 'other_user_name'],
                );
      final offerId = _readText(
        data,
        const ['listingId', 'offerId', 'offer_id'],
      );
      final offerTitle = _readText(
        data,
        const ['listingTitle', 'offerTitle', 'offer_title'],
      );
      final typingMap = _conversationValue(data, const ['typing']);
      final typingUpdatedAtMap =
          _conversationValue(data, const ['typingUpdatedAt']);
      var isOtherTyping = false;
      if (typingMap is Map) {
        final rawTyping = typingMap[otherParticipantId] == true;
        final updatedAt = typingUpdatedAtMap is Map
            ? parseFirestoreDateTime(typingUpdatedAtMap[otherParticipantId])
            : null;
        isOtherTyping = rawTyping &&
            (updatedAt == null ||
                DateTime.now().difference(updatedAt.toLocal()) <
                    const Duration(seconds: 8));
      }
      _bindPresenceListener(otherParticipantId);
      final unreadMap = _conversationValue(
        data,
        const ['unreadCount', 'unread_count'],
      );
      final unreadCount = unreadMap is Map<String, dynamic>
          ? ((unreadMap[widget.currentUserId] as int?) ?? 0)
          : unreadMap is Map
              ? ((unreadMap[widget.currentUserId] as num?)?.toInt() ?? 0)
              : 0;
      final participantChanged = otherParticipantId != _otherParticipantId;

      if (mounted) {
        setState(() {
          _participants = participants;
          _participantNames = participantNames;
          _otherParticipantId = otherParticipantId;
          _otherParticipantName = otherParticipantName;
          if (participantChanged) {
            _otherParticipantPhotoSource = '';
            _otherParticipantPhotoUrl = '';
          }
          _offerId = offerId;
          _conversationOfferTitle = offerTitle;
          _isOtherTyping = isOtherTyping;
          final lastReadAt = _conversationValue(
            data,
            const ['lastReadAt', 'last_read_at'],
          );
          _lastReadAt = lastReadAt is Map<String, dynamic>
              ? lastReadAt
              : lastReadAt is Map
                  ? Map<String, dynamic>.from(lastReadAt)
                  : const {};
          _metaLoaded = true;
          _isBlocked = isConversationBlocked(data);
          _isBlockedForCurrentUser =
              isConversationBlockedForUser(data, widget.currentUserId);
          _isBlockedByAnotherParticipant =
              isConversationBlockedByOtherUser(data, widget.currentUserId);
          _isArchivedForCurrentUser =
              isConversationArchivedForUser(data, widget.currentUserId);
        });
      }

      if (unreadCount > 0) {
        _markAsRead();
      }
    }, onError: (error, stackTrace) {
      _debugMessagingAccess(
        'conversation-document-listen-error',
        error: error,
        firestorePath: 'conversations/${widget.conversationId}',
      );
    });
  }

  void _handleConversationRemoved({required bool showMessage}) {
    if (_hasHandledConversationRemoval || !mounted) return;
    _hasHandledConversationRemoval = true;
    if (showMessage) {
      showErrorSnackBar(context, 'Conversation introuvable ou supprimée.');
    }
    Navigator.of(context).maybePop();
  }

  String? _readReceiptLabel(DateTime? sentAt) {
    if (sentAt == null) return null;

    final otherParticipantId = _participants.firstWhere(
      (participantId) => participantId != widget.currentUserId,
      orElse: () => '',
    );
    if (otherParticipantId.isEmpty) return null;

    final raw = _lastReadAt[otherParticipantId];
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

  Future<void> _sendMessageCf({
    required String text,
    List<ConversationAttachmentInput> attachments = const [],
  }) async {
    Object? firstError;
    try {
      await ConversationService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        attachments: attachments,
      );
      return;
    } catch (error) {
      if (_messagingErrorCode(error) != 'unauthenticated') rethrow;
      firstError = error;
    }
    // Auth token may have expired — refresh and retry once
    final retryReady = await _ensureMessagingAccess(
      interactive: false,
      forceRefreshToken: true,
      forceRefreshAppCheckToken: true,
    );
    if (!retryReady) throw firstError;
    await ConversationService.sendMessage(
      conversationId: widget.conversationId,
      text: text,
      attachments: attachments,
    );
  }

  Future<void> _sendMessage() async {
    final rawDraft = _controller.text;
    final text = rawDraft.trim();
    if (text.isEmpty || _isSending) return;
    if (_isBlocked) {
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

    final optimisticMessage = _OptimisticMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      sentAt: DateTime.now(),
      senderName: authUser.displayName?.trim() ?? '',
      status: _OptimisticMessageStatus.sending,
    );

    setState(() {
      _isSending = true;
      _hasDraftText = false;
      _optimisticMessages.insert(0, optimisticMessage);
    });
    _controller.clear();
    _scheduleTypingUpdate(false);

    _scrollToLatestMessage(force: true);

    try {
      final ready = await _ensureMessagingAccess(interactive: true);
      if (!ready) {
        _markOptimisticMessageFailed(optimisticMessage.id);
        if (_controller.text.trim().isEmpty) {
          _controller.value = TextEditingValue(
            text: rawDraft,
            selection: TextSelection.collapsed(offset: rawDraft.length),
          );
        }
        return;
      }
      await _sendMessageCf(text: text);

      unawaited(_markAsRead());
      _removeOptimisticMessage(optimisticMessage.id);
      _scrollToLatestMessage(force: true);
    } catch (error) {
      _debugMessagingAccess(
        'send-message-failed',
        error: error,
        firestorePath: 'conversations/${widget.conversationId}',
      );
      if (!mounted) return;
      _markOptimisticMessageFailed(optimisticMessage.id);
      if (_controller.text.trim().isEmpty) {
        _controller.value = TextEditingValue(
          text: rawDraft,
          selection: TextSelection.collapsed(offset: rawDraft.length),
        );
      }
      showErrorSnackBar(
        context,
        _sendMessageErrorMessage(error),
      );
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
      final index =
          _optimisticMessages.indexWhere((message) => message.id == id);
      if (index < 0) return;
      _optimisticMessages[index] = _optimisticMessages[index].copyWith(
        status: _OptimisticMessageStatus.failed,
      );
    });
  }

  Future<void> _retryOptimisticMessage(_OptimisticMessage message) async {
    if (_isSending || _isBlocked) return;

    setState(() {
      _isSending = true;
      final index = _optimisticMessages.indexWhere(
        (item) => item.id == message.id,
      );
      if (index >= 0) {
        _optimisticMessages[index] = message.copyWith(
          status: _OptimisticMessageStatus.sending,
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
      showErrorSnackBar(
        context,
        'Le message n’a pas pu être renvoyé.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _handleConversationAction(
      _ConversationThreadAction action) async {
    try {
      final ready = await _ensureMessagingAccess(interactive: true);
      if (!mounted) return;
      if (!ready) return;
      switch (action) {
        case _ConversationThreadAction.archive:
          await ConversationService.archiveConversation(
              conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation archivee.');
          return;
        case _ConversationThreadAction.unarchive:
          await ConversationService.unarchiveConversation(
              conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation restauree.');
          return;
        case _ConversationThreadAction.block:
          await ConversationService.blockConversation(
              conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation bloquee.');
          return;
        case _ConversationThreadAction.unblock:
          await ConversationService.unblockConversation(
              conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation debloquee.');
          return;
        case _ConversationThreadAction.adminUnblock:
          await ConversationService.adminUnblockConversation(
              conversationId: widget.conversationId);
          if (!mounted) return;
          setState(() {
            _isBlocked = false;
            _isBlockedForCurrentUser = false;
            _isBlockedByAnotherParticipant = false;
          });
          showSuccessSnackBar(context, 'Conversation debloquee par admin.');
          return;
        case _ConversationThreadAction.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              final overlayTheme = ctx.prestoOverlayTheme;
              return AlertDialog(
                backgroundColor: overlayTheme.surfaceColor,
                surfaceTintColor: overlayTheme.surfaceTintColor,
                shape: overlayTheme.dialogShape,
                title: const Text('Supprimer la conversation'),
                content: const Text(
                  'Cette action est irreversible. Tous les messages seront supprimes.',
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
              conversationId: widget.conversationId);
          if (!mounted) return;
          _hasHandledConversationRemoval = true;
          showSuccessSnackBar(context, 'Conversation supprimee.');
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

  Widget _buildStateBanner() {
    if (_isBlocked) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: _ConversationBanner(
          icon: Icons.block_rounded,
          color: const Color(0xFFB91C1C),
          message: _isBlockedForCurrentUser
              ? 'Vous avez bloque cette conversation. Debloquez-la pour reprendre les echanges.'
              : _isBlockedByAnotherParticipant
                  ? _isAdminViewer
                      ? 'Cette conversation a ete bloquee par un participant. Un admin peut la debloquer.'
                      : 'Cette conversation a ete bloquee par l autre participant.'
                  : 'Cette conversation est actuellement bloquee.',
        ),
      );
    }

    if (_isArchivedForCurrentUser) {
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

  void _applyInitialDraftIfNeeded(bool hasMessages) {
    if (_didApplyInitialDraft || hasMessages) return;

    final initialDraft = widget.initialDraftText?.trim() ?? '';
    if (initialDraft.isEmpty || _controller.text.trim().isNotEmpty) {
      _didApplyInitialDraft = true;
      return;
    }

    _didApplyInitialDraft = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.value = TextEditingValue(
        text: initialDraft,
        selection: TextSelection.collapsed(offset: initialDraft.length),
      );
    });
  }

  Widget _buildSafetyReminderBanner() {
    if (!_showSafetyReminder) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              color: Color(0xFFB91C1C),
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ne partagez jamais de codes, mots de passe ou informations bancaires.',
                style: kPrestoMetaTextStyle.copyWith(
                  color: const Color(0xFFB91C1C),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Masquer',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _showSafetyReminder = false),
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFFB91C1C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (!_isOtherTyping) return const SizedBox.shrink();

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
            '$_headerDisplayName écrit…',
            style: kPrestoMetaTextStyle.copyWith(
              color: kWhatsappGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiStrip() {
    if (!_showEmojiStrip || _isBlocked) return const SizedBox.shrink();

    const emojis = ['👍', '🙏', '😊', '👌', '🔥', '💬'];
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
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 19),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final selection = _controller.selection;
    final text = _controller.text;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  String _safeAttachmentName(String name, String fallback) {
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

  String _mimeTypeForName(String name, String fallback) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.gif')) return 'image/gif';
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.txt')) return 'text/plain';
    if (lowerName.endsWith('.doc')) return 'application/msword';
    if (lowerName.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return fallback;
  }

  String _attachmentMessageText(_MessageAttachment attachment) {
    if (attachment.type == 'image') return 'Photo : ${attachment.name}';
    if (attachment.type == 'audio') return 'Note vocale';
    return 'Document : ${attachment.name}';
  }

  Future<void> _pickAndSendPhoto() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      showErrorSnackBar(context, 'Connectez-vous pour envoyer une photo.');
      return;
    }

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1920,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final name = _safeAttachmentName(picked.name, 'photo.jpg');
    await _uploadAndSendAttachment(
      uid: authUser.uid,
      type: 'image',
      name: name,
      bytes: bytes,
      mimeType: picked.mimeType ?? _mimeTypeForName(name, 'image/jpeg'),
    );
  }

  Future<void> _pickAndSendDocument() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      showErrorSnackBar(context, 'Connectez-vous pour envoyer un document.');
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'txt'],
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

    final name = _safeAttachmentName(file.name, 'document.pdf');
    await _uploadAndSendAttachment(
      uid: authUser.uid,
      type: 'document',
      name: name,
      bytes: bytes,
      mimeType: _mimeTypeForName(name, 'application/pdf'),
    );
  }

  Future<ProcessedConversationPhoto> _processPhotoWithRetry(
      String storagePath) async {
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
    if (_isBlocked) {
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
      final path = 'messageAttachments/$uid/${widget.conversationId}/'
          '${timestamp}_${_safeAttachmentName(name, 'piece-jointe')}';
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

      final attachment = _MessageAttachment(
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
      showErrorSnackBar(
        context,
        'La pièce jointe n’a pas pu être envoyée.',
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  Future<void> _sendAttachmentMessage(_MessageAttachment attachment) async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final draftText = _controller.text.trim();
    final text =
        draftText.isEmpty ? _attachmentMessageText(attachment) : draftText;
    final optimisticMessage = _OptimisticMessage(
      id: 'local-attachment-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      attachments: [attachment],
      sentAt: DateTime.now(),
      senderName: authUser.displayName?.trim() ?? '',
      status: _OptimisticMessageStatus.sending,
    );

    setState(() {
      _isSending = true;
      if (draftText.isNotEmpty) {
        _controller.clear();
        _hasDraftText = false;
      }
      _optimisticMessages.insert(0, optimisticMessage);
    });
    _scrollToLatestMessage(force: true);

    try {
      await ConversationService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        attachments: [attachment.toInput()],
      );
      unawaited(_markAsRead());
      _removeOptimisticMessage(optimisticMessage.id);
      _scrollToLatestMessage(force: true);
    } catch (error) {
      debugPrint('[ConversationThread] send attachment error: $error');
      _markOptimisticMessageFailed(optimisticMessage.id);
      if (!mounted) return;
      showErrorSnackBar(
          context, 'La pièce jointe est prête mais l’envoi a échoué.');
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
                leading:
                    const Icon(Icons.description_outlined, color: kPrestoBlue),
                title: const Text('Document'),
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
    if (kIsWeb) {
      showErrorSnackBar(
        context,
        'Les notes vocales ne sont pas disponibles dans le navigateur.',
      );
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
      path = await createTempAudioPath(
        prefix: 'note_vocale',
        extension: 'm4a',
      );
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
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
          unawaited(_stopAndSendVoiceNote());
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
    final recorder = _voiceRecorder;
    final path = _currentRecordingPath;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _voiceRecorder = null;
        _currentRecordingPath = null;
        _recordingDuration = Duration.zero;
      });
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

  Future<void> _stopAndSendVoiceNote() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final recorder = _voiceRecorder;
    final path = _currentRecordingPath;
    final duration = _recordingDuration;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _voiceRecorder = null;
        _currentRecordingPath = null;
        _recordingDuration = Duration.zero;
      });
    }
    if (recorder == null || path == null) return;
    try {
      await recorder.stop();
    } catch (_) {}
    recorder.dispose();
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      deleteTempFile(path);
      if (mounted) {
        showErrorSnackBar(
            context, 'Connectez-vous pour envoyer une note vocale.');
      }
      return;
    }
    Uint8List bytes;
    try {
      bytes = await readTempFile(path);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
            context, 'Erreur lors de la lecture de la note vocale.');
      }
      return;
    } finally {
      deleteTempFile(path);
    }
    final secs = duration.inSeconds;
    final name = 'note_vocale_${secs}s.m4a';
    await _uploadAndSendAttachment(
      uid: authUser.uid,
      type: 'audio',
      name: name,
      bytes: bytes,
      mimeType: 'audio/mp4',
    );
  }

  Future<void> _openAttachment(_MessageAttachment attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) {
      showErrorSnackBar(context, 'Lien de pièce jointe invalide.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showErrorSnackBar(context, 'Impossible d’ouvrir cette pièce jointe.');
    }
  }

  Widget _buildAttachmentPreview(_MessageAttachment attachment) {
    if (attachment.type == 'image') {
      final fullUrl =
          attachment.url.isNotEmpty ? attachment.url : attachment.thumbnailUrl;
      return GestureDetector(
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
      );
    }

    if (attachment.type == 'audio') {
      return _VoiceNotePlayer(url: attachment.url);
    }

    return InkWell(
      onTap: () => unawaited(_openAttachment(attachment)),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, color: kPrestoBlue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kPrestoBodyTextStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreviews(List<_MessageAttachment> attachments) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments) ...[
          _buildAttachmentPreview(attachment),
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
      onForegroundImageError: (error, stackTrace) {
        debugPrint(
          '[ConversationThread] bubble avatar load failed '
          'participantId=$_otherParticipantId url=$_otherParticipantPhotoUrl '
          'error=$error',
        );
      },
      child: _otherParticipantPhotoUrl.isEmpty
          ? Text(
              _conversationInitial(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            )
          : null,
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isMine,
    required String senderName,
    required DateTime? sentAt,
    List<_MessageAttachment> attachments = const [],
    String? readReceipt,
    String? statusLabel,
    bool failed = false,
    bool groupedWithOlder = false,
    bool groupedWithNewer = false,
    VoidCallback? onRetry,
    Future<void> Function()? onLongPress,
  }) {
    final labelParts = <String>[
      _formatMessageTimestamp(sentAt),
      if (readReceipt != null) readReceipt,
      if (statusLabel != null) statusLabel,
    ];

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
            bottomLeft: Radius.circular(!isMine && groupedWithOlder
                ? 8
                : isMine
                    ? 18
                    : 4),
            bottomRight: Radius.circular(isMine && groupedWithOlder
                ? 8
                : isMine
                    ? 4
                    : 18),
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
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
            _buildAttachmentPreviews(attachments),
            if (text.isNotEmpty)
              Text(
                text,
                style: kPrestoBodyTextStyle.copyWith(
                  color: const Color(0xFF111827),
                  height: 1.3,
                  fontSize: 15,
                ),
              ),
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
                        color: Color(0xFFB91C1C),
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
                value: _isArchivedForCurrentUser
                    ? _ConversationThreadAction.unarchive
                    : _ConversationThreadAction.archive,
                child:
                    Text(_isArchivedForCurrentUser ? 'Restaurer' : 'Archiver'),
              ),
              if (_isBlockedForCurrentUser)
                const PopupMenuItem<_ConversationThreadAction>(
                  value: _ConversationThreadAction.unblock,
                  child: Text('Debloquer'),
                )
              else if (_isBlockedByAnotherParticipant && _isAdminViewer)
                const PopupMenuItem<_ConversationThreadAction>(
                  value: _ConversationThreadAction.adminUnblock,
                  child: Text('Debloquer en admin'),
                )
              else if (_isBlockedByAnotherParticipant)
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
                child: Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
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
              _buildStateBanner(),
              _buildSafetyReminderBanner(),
              _buildTypingIndicator(),
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
                                    kPrestoOrange),
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
                            if (_messagingErrorCode(snapshot.error) ==
                                'permission-denied') {
                              _retryMessageStreamAccessAfterDenied(
                                  snapshot.error);
                            }
                            final message =
                                _messageStreamErrorMessage(snapshot.error);
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
                          _applyInitialDraftIfNeeded(liveDocs.isNotEmpty);
                          final docs = _mergeMessageDocs(liveDocs);
                          final visibleItemCount =
                              docs.length + _optimisticMessages.length;
                          final canLoadMore = docs.isNotEmpty &&
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
                                          () => _showNewMessagesButton = false);
                                    });
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 8, 6, 16),
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
                                                      liveDocs),
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
                                                      size: 16),
                                              label: Text(
                                                _isLoadingMoreMessages
                                                    ? 'Chargement...'
                                                    : 'Charger les messages plus anciens',
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFF6B7280),
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
                                        statusLabel: optimisticMessage.status ==
                                                _OptimisticMessageStatus.failed
                                            ? 'Non envoyé'
                                            : 'Envoi...',
                                        failed: optimisticMessage.status ==
                                            _OptimisticMessageStatus.failed,
                                        onRetry: optimisticMessage.status ==
                                                _OptimisticMessageStatus.failed
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
                                    final senderId = ((data['senderId'] ??
                                                data['sender_id']) ??
                                            '')
                                        .toString();
                                    final senderName = ((data['senderName'] ??
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
                                    final showDateChip = sentAt != null &&
                                        (olderMessageDate == null ||
                                            !_isSameCalendarDay(
                                                sentAt, olderMessageDate));
                                    final isMine =
                                        senderId == widget.currentUserId;
                                    final readReceipt = isMine
                                        ? _readReceiptLabel(sentAt)
                                        : null;
                                    final messageDocId = docs[docIndex].id;
                                    final attachments =
                                        _MessageAttachment.fromList(
                                      data['attachments'],
                                    );
                                    final newerSenderId = docIndex > 0
                                        ? ((docs[docIndex - 1]
                                                        .data()['senderId'] ??
                                                    docs[docIndex - 1]
                                                        .data()['sender_id']) ??
                                                '')
                                            .toString()
                                        : '';
                                    final olderSenderId = docIndex + 1 <
                                            docs.length
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
                                      attachments: attachments,
                                      readReceipt: readReceipt,
                                      statusLabel: isMine && readReceipt == null
                                          ? 'Envoyé'
                                          : null,
                                      groupedWithNewer: groupedWithNewer,
                                      groupedWithOlder: groupedWithOlder,
                                      onLongPress: isMine
                                          ? () async {
                                              final scaffoldMessenger =
                                                  ScaffoldMessenger.of(context);
                                              final confirmed =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) {
                                                  final overlayTheme =
                                                      ctx.prestoOverlayTheme;
                                                  return AlertDialog(
                                                    backgroundColor:
                                                        overlayTheme
                                                            .surfaceColor,
                                                    surfaceTintColor:
                                                        overlayTheme
                                                            .surfaceTintColor,
                                                    shape: overlayTheme
                                                        .dialogShape,
                                                    title: const Text(
                                                        'Supprimer ce message'),
                                                    content: const Text(
                                                      'Ce message sera definitivement supprime.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(ctx)
                                                                .pop(false),
                                                        child: const Text(
                                                            'Annuler'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(ctx)
                                                                .pop(true),
                                                        style: TextButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              Colors.red,
                                                        ),
                                                        child: const Text(
                                                            'Supprimer'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                              if (confirmed != true ||
                                                  !mounted) {
                                                return;
                                              }
                                              try {
                                                await ConversationService
                                                    .deleteMessage(
                                                  conversationId:
                                                      widget.conversationId,
                                                  messageId: messageDocId,
                                                );
                                                if (!mounted) return;
                                                scaffoldMessenger.showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Message supprime.')),
                                                );
                                              } catch (error) {
                                                if (!mounted) return;
                                                scaffoldMessenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Impossible de supprimer ce message : $error'),
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
                                        _buildThreadDateChip(sentAt),
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
                                        Icons.keyboard_arrow_down_rounded),
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
                          IconButton.filledTonal(
                            tooltip: 'Ajouter une pièce jointe',
                            visualDensity: VisualDensity.compact,
                            onPressed: (_isBlocked ||
                                    _isUploadingAttachment ||
                                    _isSending)
                                ? null
                                : _showAttachmentSheet,
                            icon: const Icon(Icons.add_rounded),
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
                                controller: _controller,
                                textInputAction: TextInputAction.send,
                                enabled: !_isBlocked,
                                minLines: 1,
                                maxLines: 4,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: InputDecoration(
                                  hintText: _isBlocked
                                      ? 'Envoi indisponible : conversation bloquee'
                                      : 'Votre message...',
                                  prefixIcon: IconButton(
                                    tooltip: 'Emoji',
                                    onPressed: _isBlocked
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
                          FilledButton(
                            onPressed: (_isSending ||
                                    _isUploadingAttachment ||
                                    _isBlocked)
                                ? null
                                : _hasDraftText
                                    ? _sendMessage
                                    : () =>
                                        unawaited(_showVoiceRecordingSheet()),
                            style: FilledButton.styleFrom(
                              backgroundColor: kWhatsappGreen,
                              foregroundColor: Colors.white,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(11),
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

enum _OptimisticMessageStatus { sending, failed }

class _OptimisticMessage {
  final String id;
  final String text;
  final List<_MessageAttachment> attachments;
  final DateTime sentAt;
  final String senderName;
  final _OptimisticMessageStatus status;

  const _OptimisticMessage({
    required this.id,
    required this.text,
    this.attachments = const [],
    required this.sentAt,
    required this.senderName,
    required this.status,
  });

  _OptimisticMessage copyWith({
    _OptimisticMessageStatus? status,
  }) {
    return _OptimisticMessage(
      id: id,
      text: text,
      attachments: attachments,
      sentAt: sentAt,
      senderName: senderName,
      status: status ?? this.status,
    );
  }
}

class _MessageAttachment {
  final String type;
  final String name;
  final String url;
  final String thumbnailUrl;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;

  const _MessageAttachment({
    required this.type,
    required this.name,
    required this.url,
    String? thumbnailUrl,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
  }) : thumbnailUrl = thumbnailUrl ?? url;

  static List<_MessageAttachment> fromList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => _MessageAttachment.fromMap(entry))
        .whereType<_MessageAttachment>()
        .toList(growable: false);
  }

  static _MessageAttachment? fromMap(Map<dynamic, dynamic> data) {
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
    return _MessageAttachment(
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

class _OfferPreview {
  final String id;
  final String title;
  final String priceLabel;
  final String imageUrl;

  const _OfferPreview({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.imageUrl,
  });

  factory _OfferPreview.fromMap(String id, Map<String, dynamic> data) {
    final title =
        _firstText(data, const ['title', 'listingTitle', 'offerTitle']);
    final priceValue = _firstValue(data, const [
      'price',
      'budget',
      'amount',
      'salary',
      'dailyRate',
    ]);
    final priceLabel = _formatOfferPrice(priceValue);
    final imageUrl = _firstImageUrl(data);

    return _OfferPreview(
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
    final direct =
        _firstText(data, const ['thumbnailUrl', 'imageUrl', 'photoUrl']);
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
        final value =
            (entry['url'] ?? entry['downloadUrl'] ?? '').toString().trim();
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
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConversationPatternPainter(),
        size: Size.infinite,
      ),
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

class _VoiceNotePlayer extends StatefulWidget {
  final String url;

  const _VoiceNotePlayer({required this.url});

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

  Future<void> _toggle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (_isPlaying) {
        await _player.pause();
      } else if (_isPaused) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.url));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = PlayerState.stopped;
        _isLoading = false;
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

String _formatMessageTimestamp(DateTime? date) {
  if (date == null) return 'Envoi...';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatThreadDateLabel(DateTime? date) {
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

String _formatPresenceSeenAt(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  return 'le ${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}

bool _isDeletedUserMap(Map<String, dynamic>? data) {
  return DeletedUserProfile.isDeletedMap(data);
}

String _deletedAwareDisplayName(
  Map<String, dynamic>? data,
  String? fallbackName,
) {
  return DeletedUserProfile.displayName(
    isDeleted: _isDeletedUserMap(data),
    fallbackName: fallbackName,
  );
}

Widget _deletedAwareAvatar({
  required Map<String, dynamic>? data,
  required Widget fallback,
  double radius = 22,
}) {
  if (_isDeletedUserMap(data)) {
    return DeletedUserAvatar(radius: radius);
  }

  return fallback;
}
