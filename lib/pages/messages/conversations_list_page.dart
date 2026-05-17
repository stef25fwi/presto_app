import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart';

import '../../app/presto_overlay_theme.dart';
import '../../constants.dart';
import '../../models/conversation_summary.dart';
import '../../services/conversation_service.dart';
import '../../services/firestore_date_parser.dart';
import '../../utils/friendly_snackbar.dart';
import 'conversation_thread_page.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);
const kMessagesPageBackground = Color(0xFFFFFEFE);
const kWhatsappGreen = Color(0xFF25D366);
const kMessagesStatusBarStyle = SystemUiOverlayStyle(
  statusBarColor: kPrestoBlue,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

class ConversationsListPage extends StatefulWidget {
  final String? initialConversationId;
  final String? initialDraftText;
  final String appBarTitle;

  const ConversationsListPage({
    super.key,
    this.initialConversationId,
    this.initialDraftText,
    this.appBarTitle = 'Mes messages',
  });

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _hiddenConversationIds = <String>{};
  final List<String> _adminConversationLoadLogs = <String>[];
  bool _didHandleInitialConversation = false;
  bool _isResolvingInitialConversation = false;
  int _initialConversationResolveAttempts = 0;
  Timer? _initialConversationRetryTimer;
  _ConversationListFilter _activeFilter = _ConversationListFilter.all;
  Stream<_ConversationQueryState>? _conversationStateStream;
  String? _conversationStateUserId;
  bool? _conversationStateAdminMode;
  String? _adminStatusUid;
  bool _adminStatusReady = false;
  bool _adminStatusLoading = false;
  bool _isAdminViewer = false;

  void _appendAdminConversationLog(String message) {
    if (!_isAdminViewer || !mounted) return;

    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    final line = '[$stamp] $message';

    setState(() {
      _adminConversationLoadLogs.insert(0, line);
      if (_adminConversationLoadLogs.length > 12) {
        _adminConversationLoadLogs.removeRange(
            12, _adminConversationLoadLogs.length);
      }
    });
  }

  Future<void> _refreshAdminViewerStatus(User user) async {
    if (_adminStatusUid == user.uid &&
        (_adminStatusReady || _adminStatusLoading)) {
      return;
    }
    _adminStatusUid = user.uid;
    _adminStatusReady = false;
    _adminStatusLoading = true;

    bool isAdmin = false;
    var adminSource = 'none';
    var detectedClaims = const <String, dynamic>{};
    try {
      final tokenResult = await user.getIdTokenResult(true);
      final claims = tokenResult.claims ?? const <String, dynamic>{};
      detectedClaims = claims;
      isAdmin = _hasAdminAccess(claims);
      if (isAdmin) {
        adminSource = 'claims';
      }

      if (!isAdmin) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = userDoc.data() ?? const <String, dynamic>{};
        isAdmin = _hasAdminAccess(data);
        if (isAdmin) {
          adminSource = 'users/${user.uid}';
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
            '[MessagesList] admin status check failed uid=${user.uid} error=$error');
      }
      isAdmin = false;
    }

    if (!mounted) return;
    setState(() {
      final adminModeChanged = _isAdminViewer != isAdmin;
      _isAdminViewer = isAdmin;
      _adminStatusReady = true;
      _adminStatusLoading = false;
      if (adminModeChanged) {
        _conversationStateStream = null;
        _conversationStateAdminMode = null;
      }
      if (!isAdmin) {
        _adminConversationLoadLogs.clear();
      } else if (_adminConversationLoadLogs.isEmpty) {
        _adminConversationLoadLogs.add(
          '[init] Journal admin actif source=$adminSource uid=${user.uid}.',
        );
      }
    });
    if (kDebugMode) {
      debugPrint(
        '[MessagesList] adminViewer uid=${user.uid} isAdmin=$isAdmin '
        'source=$adminSource claimsKeys=${detectedClaims.keys.toList()..sort()}',
      );
    }
  }

  bool _hasAdminAccess(Map<String, dynamic> data) {
    final roles = _rolesFromValue(data['roles']);
    final role = _firstNormalizedText(data, const [
      'primaryRole',
      'role',
      'adminRole',
    ]);
    return roles.contains('admin') ||
        roles.contains('superadmin') ||
        role == 'admin' ||
        role == 'superadmin' ||
        data['admin'] == true ||
        data['isAdmin'] == true ||
        data['superadmin'] == true ||
        data['superAdmin'] == true;
  }

  Set<String> _rolesFromValue(dynamic value) {
    final Iterable<dynamic> rawValues;
    if (value is String) {
      rawValues = value.split(RegExp(r'[,\s]+'));
    } else if (value is Iterable) {
      rawValues = value;
    } else if (value is Map) {
      rawValues = value.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key);
    } else {
      return const <String>{};
    }
    return rawValues
        .map((entry) => entry.toString().trim().toLowerCase())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  String? _firstNormalizedText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim().toLowerCase();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Object? _conversationValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (value != null) return value;
    }
    return null;
  }

  @override
  void dispose() {
    _initialConversationRetryTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _isPermissionDenied(Object? error) {
    final text = (error ?? '').toString().toLowerCase();
    return text.contains('permission-denied') ||
        text.contains('permission denied');
  }

  String _conversationTitle(Map<String, dynamic> data, String userId) {
    final participantNames = _conversationValue(
      data,
      const ['participantNames', 'participant_names'],
    );
    if (participantNames is Map) {
      for (final entry in participantNames.entries) {
        if (entry.key.toString() == userId) continue;
        final value = (entry.value ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
    }

    final candidates = [
      _conversationValue(data, const ['otherUserName', 'other_user_name']),
      _conversationValue(data, const ['participantName', 'participant_name']),
      _conversationValue(
        data,
        const ['participantDisplayName', 'participant_display_name'],
      ),
      _conversationValue(data, const ['offerTitle', 'offer_title']),
    ];
    for (final candidate in candidates) {
      final value = (candidate ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'Conversation';
  }

  String _conversationPreview(Map<String, dynamic> data, String userId) {
    final lastMessage = _conversationValue(
      data,
      const ['lastMessage', 'last_message'],
    ).toString().trim();
    final lastSenderId = _conversationValue(
      data,
      const ['lastSenderId', 'last_sender_id'],
    ).toString().trim();
    final offerTitle = _conversationValue(
      data,
      const ['offerTitle', 'offer_title'],
    ).toString().trim();

    if (lastMessage.isNotEmpty) {
      if (lastSenderId == userId) {
        return 'Vous : $lastMessage';
      }
      return lastMessage;
    }

    if (offerTitle.isNotEmpty) {
      return offerTitle;
    }

    return 'Touchez pour ouvrir la conversation';
  }

  String _searchableConversationText(Map<String, dynamic> data, String userId) {
    return [
      _conversationTitle(data, userId),
      _conversationPreview(data, userId),
      _conversationValue(data, const ['offerTitle', 'offer_title']).toString(),
      _conversationValue(data, const ['lastMessage', 'last_message'])
          .toString(),
      _conversationValue(data, const ['lastSenderName', 'last_sender_name'])
          .toString(),
    ].join(' ').toLowerCase();
  }

  DateTime? _conversationSortDate(Map<String, dynamic> data) {
    return parseFirestoreDateTime(
          _conversationValue(data, const ['lastMessageAt', 'last_message_at']),
        ) ??
        parseFirestoreDateTime(
          _conversationValue(data, const ['updatedAt', 'updated_at']),
        ) ??
        parseFirestoreDateTime(
          _conversationValue(data, const ['createdAt', 'created_at']),
        );
  }

  String? _notificationConversationId(Map<String, dynamic> data) {
    final directValue = _conversationValue(
      data,
      const ['conversationId', 'conversation_id'],
    );
    final normalizedDirectValue = (directValue ?? '').toString().trim();
    if (normalizedDirectValue.isNotEmpty) {
      return normalizedDirectValue;
    }

    final routeName =
        (data['routeName'] ?? data['route_name'] ?? '').toString().trim();
    if (routeName.isEmpty) return null;
    if (!routeName.startsWith('/messages/')) return null;

    final segments = routeName.split('/');
    if (segments.length < 3) return null;
    final conversationId = Uri.decodeComponent(segments[2]).trim();
    return conversationId.isEmpty ? null : conversationId;
  }

  Stream<_ConversationQueryState> _buildConversationStateStream(String userId) {
    final isAdminMode = _isAdminViewer;
    final mode = isAdminMode ? 'admin_global' : 'user_participantIds';
    final controller = StreamController<_ConversationQueryState>();

    _appendAdminConversationLog('mode=$mode user=$userId');
    if (kDebugMode) {
      debugPrint('[MessagesList] mode=$mode user=$userId');
    }

    final query = isAdminMode
        ? FirebaseFirestore.instance
            .collection('conversations')
            .orderBy('updatedAt', descending: true)
            .limit(50)
        : FirebaseFirestore.instance
            .collection('conversations')
            .where('participantIds', arrayContains: userId)
            .orderBy('updatedAt', descending: true);

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        subscription;
    subscription = query.snapshots().listen(
      (snapshot) {
        final docs = snapshot.docs
            .map(ConversationSummary.fromFirestore)
            .toList(growable: false);
        _appendAdminConversationLog(
          'mode=$mode conversations_count=${docs.length}',
        );
        if (kDebugMode) {
          debugPrint(
            '[MessagesList] mode=$mode conversations_count=${docs.length} user=$userId',
          );
        }
        if (!controller.isClosed) {
          controller.add(
            _ConversationQueryState(
              docs: docs,
              errorsByField: const <String, Object>{},
              isLoading: false,
            ),
          );
        }
      },
      onError: (error, stackTrace) {
        _appendAdminConversationLog('mode=$mode erreur=$error');
        if (kDebugMode) {
          debugPrint(
            '[MessagesList] mode=$mode error user=$userId error=$error',
          );
        }
        if (!controller.isClosed) {
          controller.add(
            _ConversationQueryState(
              docs: const <ConversationSummary>[],
              errorsByField: <String, Object>{mode: error},
              isLoading: false,
            ),
          );
        }
      },
    );

    controller.onCancel = () async {
      _appendAdminConversationLog('mode=$mode arret_abonnement');
      await subscription.cancel();
    };

    return controller.stream;
  }

  Widget _buildAdminConversationLoadLogPanel() {
    if (!_isAdminViewer) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF7EE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCDE7C9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log admin - chargement conversations',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E5E28),
              ),
            ),
            const SizedBox(height: 8),
            if (_adminConversationLoadLogs.isEmpty)
              const Text(
                'Aucun evenement de chargement pour le moment.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F6C38),
                ),
              )
            else
              ..._adminConversationLoadLogs.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F6C38),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Stream<_ConversationQueryState> _conversationStateForUser(String userId) {
    if (_conversationStateUserId == userId &&
        _conversationStateAdminMode == _isAdminViewer &&
        _conversationStateStream != null) {
      return _conversationStateStream!;
    }

    _conversationStateUserId = userId;
    _conversationStateAdminMode = _isAdminViewer;
    _conversationStateStream = _buildConversationStateStream(userId);
    return _conversationStateStream!;
  }

  Future<void> _markConversationRead(
      String conversationId, String currentUserId) async {
    try {
      await ConversationService.markAsRead(conversationId: conversationId);
    } catch (e) {
      debugPrint('[ConversationsList] markAsRead failed: $e');
    }
  }

  Future<void> _handleConversationAction({
    required String conversationId,
    required _ConversationMenuAction action,
  }) async {
    try {
      switch (action) {
        case _ConversationMenuAction.archive:
          await ConversationService.archiveConversation(
              conversationId: conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation archivee.');
          return;
        case _ConversationMenuAction.unarchive:
          await ConversationService.unarchiveConversation(
              conversationId: conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation restauree.');
          return;
        case _ConversationMenuAction.block:
          await ConversationService.blockConversation(
              conversationId: conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation bloquee.');
          return;
        case _ConversationMenuAction.unblock:
          await ConversationService.unblockConversation(
              conversationId: conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation debloquee.');
          return;
        case _ConversationMenuAction.delete:
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
              conversationId: conversationId);
          if (!mounted) return;
          setState(() {
            _hiddenConversationIds.add(conversationId);
          });
          showSuccessSnackBar(context, 'Conversation supprimee.');
          return;
      }
    } catch (error) {
      if (!mounted) return;
      debugPrint(
        '[MessagesList] conversation action failed id=$conversationId action=$action error=$error',
      );
      showErrorSnackBar(
        context,
        'Cette action est temporairement indisponible. Reessayez dans un instant.',
      );
    }
  }

  Future<void> _openConversation(
    BuildContext context,
    ConversationSummary conversation,
    String userId,
    String? initialDraftText,
  ) async {
    final title = conversation.titleFor(userId);
    final offerTitle = conversation.offerTitle.trim();

    // Fire-and-forget : ne pas bloquer la navigation sur le réseau
    _markConversationRead(conversation.id, userId);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationThreadPage(
          conversationId: conversation.id,
          offerTitle: offerTitle.isEmpty ? title : offerTitle,
          currentUserId: userId,
          initialDraftText: initialDraftText,
        ),
      ),
    );
  }

  void _maybeOpenInitialConversation(
    BuildContext context,
    List<ConversationSummary> docs,
    String userId,
  ) {
    final initialConversationId = widget.initialConversationId?.trim() ?? '';
    if (_didHandleInitialConversation ||
        _isResolvingInitialConversation ||
        initialConversationId.isEmpty) {
      return;
    }

    final match = docs.where((doc) => doc.id == initialConversationId).toList();

    if (match.isNotEmpty) {
      _didHandleInitialConversation = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _openConversation(
          context,
          match.first,
          userId,
          widget.initialDraftText,
        );
      });
      return;
    }

    unawaited(
      _resolveInitialConversationById(
        context,
        userId: userId,
        conversationId: initialConversationId,
      ),
    );
  }

  Future<void> _resolveInitialConversationById(
    BuildContext context, {
    required String userId,
    required String conversationId,
  }) async {
    _isResolvingInitialConversation = true;
    _initialConversationResolveAttempts += 1;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();

      final data = snapshot.data();
      if (data != null) {
        final normalizedData = Map<String, dynamic>.from(data);
        final conversation = ConversationSummary.fromMap(
          snapshot.id,
          normalizedData,
          assumedParticipants: <String>[userId],
        );

        if (conversation.includesUser(userId)) {
          _didHandleInitialConversation = true;
          if (!context.mounted) return;
          await _openConversation(
            context,
            conversation,
            userId,
            widget.initialDraftText,
          );
          return;
        }
      }

      if (_initialConversationResolveAttempts < 8 && mounted) {
        _initialConversationRetryTimer?.cancel();
        _initialConversationRetryTimer = Timer(
          const Duration(milliseconds: 350),
          () {
            if (!mounted) return;
            unawaited(
              _resolveInitialConversationById(
                context,
                userId: userId,
                conversationId: conversationId,
              ),
            );
          },
        );
        return;
      }

      _didHandleInitialConversation = true;
      if (!context.mounted) return;
      showErrorSnackBar(context, 'Conversation introuvable ou inaccessible.');
    } finally {
      _isResolvingInitialConversation = false;
    }
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        children: [
          _ConversationFilterChip(
            label: 'Tous',
            selected: _activeFilter == _ConversationListFilter.all,
            onTap: () =>
                setState(() => _activeFilter = _ConversationListFilter.all),
          ),
          const SizedBox(width: 8),
          _ConversationFilterChip(
            label: 'Non lus',
            selected: _activeFilter == _ConversationListFilter.unread,
            onTap: () =>
                setState(() => _activeFilter = _ConversationListFilter.unread),
          ),
          const SizedBox(width: 8),
          _ConversationFilterChip(
            label: 'Archives',
            selected: _activeFilter == _ConversationListFilter.archived,
            onTap: () => setState(
                () => _activeFilter = _ConversationListFilter.archived),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher une conversation',
          prefixIcon: const Icon(Icons.search_rounded, color: kPrestoBlue),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kPrestoBlue, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kPrestoBlue, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildWatermark() {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -0.18,
          child: Text(
            'ilipresto',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Colors.grey.withOpacity(0.07),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 42,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: kPrestoBodyTextStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsBanner({
    required Map<String, Object> errorsByField,
    required int orphanCount,
    bool hasVisibleConversations = false,
  }) {
    final shouldExposeErrors = !hasVisibleConversations || kDebugMode;
    if ((errorsByField.isEmpty || !shouldExposeErrors) && orphanCount <= 0) {
      return const SizedBox.shrink();
    }

    final lines = <String>[];
    if (orphanCount > 0) {
      lines.add(
        orphanCount == 1
            ? '1 conversation n est pas affichee pour ce compte car les metadonnees participants sont incompletes.'
            : '$orphanCount conversations ne sont pas affichees car les metadonnees participants sont incompletes.',
      );
    }
    if (errorsByField.isNotEmpty && shouldExposeErrors) {
      lines.add(_isAdminViewer
          ? 'Erreur de chargement des conversations admin. Verifiez les droits admin et les regles Firestore.'
          : 'Erreur de chargement des conversations. Verifiez les droits utilisateur et le champ participantIds.');
      if (kDebugMode) {
        for (final entry in errorsByField.entries) {
          lines.add('${entry.key}: ${entry.value}');
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD2A6)),
        ),
        child: Text(
          lines.join('\n'),
          style: kPrestoMetaTextStyle.copyWith(
            color: const Color(0xFF92400E),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesAppBarTitle() {
    return Text(
      widget.appBarTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: kPrestoAppBarTitleStyle,
    );
  }

  Widget _buildCurrentAccountBanner(User user) {
    final email = (user.email ?? '').trim();
    final uid = user.uid.trim();
    final copyValue = 'email=${email.isEmpty ? 'aucun' : email}\nuid=$uid';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC9DCF8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.verified_user_outlined,
                color: kPrestoBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compte actuellement connecté',
                    style: kPrestoMetaTextStyle.copyWith(
                      color: const Color(0xFF0F3D91),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email.isEmpty ? 'Email non disponible' : email,
                    style: kPrestoBodyTextStyle.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    'UID: $uid',
                    style: kPrestoMetaTextStyle.copyWith(
                      color: const Color(0xFF4B5563),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copier les identifiants',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: copyValue));
                if (!mounted) return;
                showSuccessSnackBar(context, 'Identifiants du compte copiés.');
              },
              icon: const Icon(
                Icons.copy_rounded,
                color: kPrestoBlue,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final currentUser = authSnapshot.data;
        final userId = currentUser?.uid;

        if (currentUser != null) {
          unawaited(_refreshAdminViewerStatus(currentUser));
        }

        if (userId == null) {
          return Scaffold(
            backgroundColor: kMessagesPageBackground,
            appBar: AppBar(
              systemOverlayStyle: kMessagesStatusBarStyle,
              backgroundColor: kPrestoOrange,
              foregroundColor: Colors.white,
              title: Text(
                widget.appBarTitle,
                style: kPrestoAppBarTitleStyle,
              ),
              centerTitle: true,
            ),
            body: Stack(
              children: [
                _buildWatermark(),
                _buildEmptyState(
                    'Connexion / inscription pour accéder à la messagerie.'),
              ],
            ),
          );
        }

        if (!_adminStatusReady || _adminStatusUid != userId) {
          return Scaffold(
            backgroundColor: kMessagesPageBackground,
            appBar: AppBar(
              systemOverlayStyle: kMessagesStatusBarStyle,
              backgroundColor: kPrestoOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: _buildMessagesAppBarTitle(),
            ),
            body: Stack(
              children: [
                _buildWatermark(),
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: kMessagesPageBackground,
          appBar: AppBar(
            systemOverlayStyle: kMessagesStatusBarStyle,
            backgroundColor: kPrestoOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: _buildMessagesAppBarTitle(),
          ),
          body: Stack(
            children: [
              _buildWatermark(),
              Column(
                children: [
                  if (currentUser != null)
                    _buildCurrentAccountBanner(currentUser),
                  _buildAdminConversationLoadLogPanel(),
                  _buildSearchField(),
                  _buildFilterTabs(),
                  Expanded(
                    child: StreamBuilder<_ConversationQueryState>(
                      stream: _conversationStateForUser(userId),
                      builder: (context, snapshot) {
                        final state = snapshot.data;

                        if ((snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                state == null) ||
                            (state?.isLoading ?? false)) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(kPrestoOrange),
                            ),
                          );
                        }

                        final docs =
                            state?.docs ?? const <ConversationSummary>[];
                        final errorsByField =
                            state?.errorsByField ?? const <String, Object>{};
                        _maybeOpenInitialConversation(context, docs, userId);

                        final query =
                            _searchController.text.trim().toLowerCase();
                        var orphanCount = 0;
                        final conversations = docs;

                        final visibleConversations =
                            conversations.where((conversation) {
                          if (_hiddenConversationIds
                              .contains(conversation.id)) {
                            return false;
                          }

                          if (!conversation.includesUser(userId)) {
                            orphanCount += 1;
                            if (kDebugMode) {
                              debugPrint(
                                '[MessagesList] orphan conversation ignored id=${conversation.id} user=$userId participants=${conversation.participants}',
                              );
                            }
                            return _isAdminViewer;
                          }

                          if (!conversation.hasRenderableContent) {
                            return false;
                          }

                          switch (_activeFilter) {
                            case _ConversationListFilter.archived:
                              return conversation.isArchivedForUser(userId);
                            case _ConversationListFilter.unread:
                              return !conversation.isArchivedForUser(userId) &&
                                  conversation.unreadForUser(userId) > 0;
                            case _ConversationListFilter.all:
                              return !conversation.isArchivedForUser(userId);
                          }
                        }).toList(growable: false);

                        final filteredConversations = visibleConversations
                            .where((conversation) =>
                                conversation.matchesQuery(userId, query))
                            .toList(growable: false);

                        if (filteredConversations.isEmpty) {
                          final message = errorsByField.isNotEmpty &&
                                  docs.isEmpty
                              ? (_isPermissionDenied(errorsByField.values.first)
                                  ? 'Acces refuse aux conversations. Verifiez les regles Firestore et les participants enregistres.'
                                  : 'Erreur de chargement des conversations. Consultez les logs de debug.')
                              : query.isNotEmpty
                                  ? 'Aucune conversation ne correspond a votre recherche.'
                                  : _activeFilter ==
                                          _ConversationListFilter.archived
                                      ? 'Aucune conversation archivee.'
                                      : orphanCount > 0
                                          ? 'Aucune conversation affichable pour le moment. Le diagnostic ci-dessous signale des metadonnees participants incompletes sur certaines conversations.'
                                          : 'Aucune conversation pour le moment.';

                          return Column(
                            children: [
                              _buildDiagnosticsBanner(
                                errorsByField: errorsByField,
                                orphanCount: orphanCount,
                                hasVisibleConversations: false,
                              ),
                              Expanded(child: _buildEmptyState(message)),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _buildDiagnosticsBanner(
                              errorsByField: errorsByField,
                              orphanCount: orphanCount,
                              hasVisibleConversations:
                                  filteredConversations.isNotEmpty,
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 6, 10, 18),
                                itemCount: filteredConversations.length,
                                itemBuilder: (context, index) {
                                  final conversation =
                                      filteredConversations[index];
                                  final offerTitle = conversation.offerTitle;
                                  final title = conversation.titleFor(userId);
                                  final preview =
                                      conversation.previewFor(userId);
                                  final unreadCount =
                                      conversation.unreadForUser(userId);
                                  final archived =
                                      conversation.isArchivedForUser(userId);
                                  final blocked = conversation.isBlocked;
                                  final blockedForUser =
                                      conversation.isBlockedForUser(userId);
                                  final lastDate = conversation.sortDate;

                                  Future<void> openConversation() {
                                    return _openConversation(
                                      context,
                                      conversation,
                                      userId,
                                      null,
                                    );
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: Slidable(
                                      key: ValueKey<String>(
                                          'conversation-${conversation.id}'),
                                      startActionPane: ActionPane(
                                        motion: const DrawerMotion(),
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) =>
                                                _handleConversationAction(
                                              conversationId: conversation.id,
                                              action: archived
                                                  ? _ConversationMenuAction
                                                      .unarchive
                                                  : _ConversationMenuAction
                                                      .archive,
                                            ),
                                            backgroundColor:
                                                const Color(0xFF6B7280),
                                            foregroundColor: Colors.white,
                                            icon: archived
                                                ? Icons.unarchive_outlined
                                                : Icons.archive_outlined,
                                            label: archived
                                                ? 'Restaurer'
                                                : 'Archiver',
                                          ),
                                          SlidableAction(
                                            onPressed: (_) =>
                                                _handleConversationAction(
                                              conversationId: conversation.id,
                                              action: blockedForUser
                                                  ? _ConversationMenuAction
                                                      .unblock
                                                  : _ConversationMenuAction
                                                      .block,
                                            ),
                                            backgroundColor:
                                                const Color(0xFFB91C1C),
                                            foregroundColor: Colors.white,
                                            icon: blockedForUser
                                                ? Icons.lock_open_rounded
                                                : Icons.block_rounded,
                                            label: blockedForUser
                                                ? 'Debloquer'
                                                : 'Bloquer',
                                          ),
                                        ],
                                      ),
                                      endActionPane: ActionPane(
                                        motion: const DrawerMotion(),
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) =>
                                                _handleConversationAction(
                                              conversationId: conversation.id,
                                              action: _ConversationMenuAction
                                                  .delete,
                                            ),
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            icon: Icons.delete_outline_rounded,
                                            label: 'Supprimer',
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.white.withOpacity(0.98),
                                        borderRadius: BorderRadius.circular(16),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          onTap: openConversation,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            padding: const EdgeInsets.fromLTRB(
                                                8, 12, 8, 12),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.black
                                                      .withOpacity(0.06),
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                GestureDetector(
                                                  onTap: openConversation,
                                                  child: Stack(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 27,
                                                        backgroundColor:
                                                            const Color(
                                                                0xFFEAF2FF),
                                                        foregroundColor:
                                                            kPrestoBlue,
                                                        child: Text(
                                                          title.isNotEmpty
                                                              ? title[0]
                                                                  .toUpperCase()
                                                              : '?',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 18,
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        right: 1,
                                                        bottom: 1,
                                                        child: Container(
                                                          width: 12,
                                                          height: 12,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: unreadCount >
                                                                    0
                                                                ? kWhatsappGreen
                                                                : const Color(
                                                                    0xFFD1D5DB),
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color:
                                                                  Colors.white,
                                                              width: 2,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              title,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  kPrestoCardTitleStyle
                                                                      .copyWith(
                                                                fontWeight: unreadCount >
                                                                        0
                                                                    ? FontWeight
                                                                        .w800
                                                                    : FontWeight
                                                                        .w700,
                                                                color: const Color(
                                                                    0xFF111827),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                            _formatTimestamp(
                                                                lastDate),
                                                            style:
                                                                kPrestoMetaTextStyle
                                                                    .copyWith(
                                                              color: unreadCount >
                                                                      0
                                                                  ? kWhatsappGreen
                                                                  : const Color(
                                                                      0xFF9CA3AF),
                                                              fontWeight:
                                                                  unreadCount >
                                                                          0
                                                                      ? FontWeight
                                                                          .w700
                                                                      : FontWeight
                                                                          .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (offerTitle
                                                              .isNotEmpty &&
                                                          offerTitle !=
                                                              title) ...[
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          offerTitle,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              kPrestoMetaTextStyle
                                                                  .copyWith(
                                                            color: const Color(
                                                                0xFF6B7280),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        preview,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            kPrestoBodyTextStyle
                                                                .copyWith(
                                                          color: unreadCount > 0
                                                              ? const Color(
                                                                  0xFF111827)
                                                              : const Color(
                                                                  0xFF6B7280),
                                                          fontWeight:
                                                              unreadCount > 0
                                                                  ? FontWeight
                                                                      .w600
                                                                  : FontWeight
                                                                      .w500,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      if (archived ||
                                                          blocked) ...[
                                                        const SizedBox(
                                                            height: 6),
                                                        Wrap(
                                                          spacing: 6,
                                                          runSpacing: 6,
                                                          children: [
                                                            if (archived)
                                                              _ConversationStateChip(
                                                                label:
                                                                    'Archivee',
                                                                color: const Color(
                                                                    0xFF6B7280),
                                                              ),
                                                            if (blocked)
                                                              _ConversationStateChip(
                                                                label: blockedForUser
                                                                    ? 'Bloquee par vous'
                                                                    : 'Bloquee',
                                                                color: const Color(
                                                                    0xFFB91C1C),
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    PopupMenuButton<
                                                        _ConversationMenuAction>(
                                                      tooltip:
                                                          'Actions conversation',
                                                      onSelected: (action) =>
                                                          _handleConversationAction(
                                                        conversationId:
                                                            conversation.id,
                                                        action: action,
                                                      ),
                                                      itemBuilder: (context) =>
                                                          [
                                                        PopupMenuItem<
                                                            _ConversationMenuAction>(
                                                          value: archived
                                                              ? _ConversationMenuAction
                                                                  .unarchive
                                                              : _ConversationMenuAction
                                                                  .archive,
                                                          child: Text(
                                                            archived
                                                                ? 'Restaurer'
                                                                : 'Archiver',
                                                          ),
                                                        ),
                                                        PopupMenuItem<
                                                            _ConversationMenuAction>(
                                                          value: blockedForUser
                                                              ? _ConversationMenuAction
                                                                  .unblock
                                                              : _ConversationMenuAction
                                                                  .block,
                                                          child: Text(
                                                            blockedForUser
                                                                ? 'Debloquer'
                                                                : 'Bloquer',
                                                          ),
                                                        ),
                                                        const PopupMenuItem<
                                                            _ConversationMenuAction>(
                                                          value:
                                                              _ConversationMenuAction
                                                                  .delete,
                                                          child: Text(
                                                            'Supprimer',
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.red),
                                                          ),
                                                        ),
                                                      ],
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.all(4),
                                                        child: Icon(
                                                          Icons
                                                              .more_horiz_rounded,
                                                          color:
                                                              Color(0xFF9CA3AF),
                                                        ),
                                                      ),
                                                    ),
                                                    if (unreadCount > 0) ...[
                                                      const SizedBox(
                                                          height: 10),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: kWhatsappGreen,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      999),
                                                        ),
                                                        child: Text(
                                                          '$unreadCount',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) return '';

    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final diff = today.difference(date).inDays;

    if (diff <= 0) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (diff == 1) return 'Hier';

    const months = <String>[
      'janv.',
      'fevr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'aout',
      'sept.',
      'oct.',
      'nov.',
      'dec.',
    ];
    return '${local.day} ${months[local.month - 1]}';
  }
}

class _ConversationQueryState {
  final List<ConversationSummary> docs;
  final Map<String, Object> errorsByField;
  final bool isLoading;

  const _ConversationQueryState({
    required this.docs,
    required this.errorsByField,
    required this.isLoading,
  });
}

enum _ConversationListFilter { all, unread, archived }

enum _ConversationMenuAction { archive, unarchive, block, unblock, delete }

class _ConversationFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConversationFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kPrestoBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? kPrestoBlue : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ConversationStateChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ConversationStateChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
