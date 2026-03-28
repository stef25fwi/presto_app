import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../services/conversation_service.dart';
import '../../services/conversation_state.dart';
import '../../services/firestore_date_parser.dart';
import '../../utils/friendly_snackbar.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kThreadMineColor = Color(0xFFD9FDD3);
const kThreadOtherColor = Colors.white;
const kThreadBackground = Color(0xFFFFFEFE);
const kWhatsappGreen = Color(0xFF25D366);

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

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _conversationSubscription;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _olderMessageDocs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? _paginationAnchorDoc;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _messageStream;
  bool _isSending = false;
  bool _isMarkingRead = false;
  bool _hasAttemptedOlderPagination = false;
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;
  List<String> _participants = const [];
  Map<String, dynamic> _lastReadAt = const {};
  bool _metaLoaded = false;
  bool _didApplyInitialDraft = false;
  bool _isBlocked = false;
  bool _isBlockedForCurrentUser = false;
  bool _isArchivedForCurrentUser = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildLiveStream({
    QueryDocumentSnapshot<Map<String, dynamic>>? anchorDoc,
  }) {
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
    super.initState();
    _messageStream = _buildLiveStream();
    _bindConversationListener();
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isPermissionDenied(Object? error) {
    final text = (error ?? '').toString().toLowerCase();
    return text.contains('permission-denied') || text.contains('permission denied');
  }

  Widget _buildWatermark() {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -0.16,
          child: Text(
            'ilipresto',
            style: TextStyle(
              fontSize: 70,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: Colors.grey.withOpacity(0.06),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadDateChip(DateTime? date) {
    final label = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '--/--/----';
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    final raw = widget.offerTitle.trim();
    if (raw.isEmpty) return '?';
    return raw.characters.first.toUpperCase();
  }

  Widget _buildThreadAppBarTitle() {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withOpacity(0.18),
          foregroundColor: Colors.white,
          child: Text(
            _conversationInitial(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.offerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kPrestoAppBarTitleStyle,
              ),
              const Text(
                'Conversation privee',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFFFF4EC),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF1A73E8),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.offerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kPrestoBodyTextStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Discussion liee a cette annonce',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kPrestoMetaTextStyle.copyWith(
                      color: const Color(0xFF6B7280),
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

  void _bindConversationListener() {
    _conversationSubscription?.cancel();
    _conversationSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final participants = (data['participants'] as List<dynamic>? ?? [])
          .map((entry) => entry.toString())
          .where((entry) => entry.isNotEmpty)
          .toList();
      final unreadMap = data['unreadCount'];
      final unreadCount = unreadMap is Map<String, dynamic>
          ? ((unreadMap[widget.currentUserId] as int?) ?? 0)
          : 0;

      if (mounted) {
        setState(() {
          _participants = participants;
          _lastReadAt = (data['lastReadAt'] as Map<String, dynamic>?) ?? const {};
          _metaLoaded = true;
          _isBlocked = isConversationBlocked(data);
          _isBlockedForCurrentUser = isConversationBlockedForUser(data, widget.currentUserId);
          _isArchivedForCurrentUser = isConversationArchivedForUser(data, widget.currentUserId);
        });
      }

      if (unreadCount > 0) {
        _markAsRead();
      }
    });
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
    final isFirstPagination = _paginationAnchorDoc == null && _olderMessageDocs.isEmpty;
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
        'Erreur lors du chargement des messages plus anciens.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreMessages = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final rawDraft = _controller.text;
    final text = rawDraft.trim();
    if (text.isEmpty || _isSending) return;
    if (_isBlocked) {
      showErrorSnackBar(context, 'Cette conversation est bloquee.');
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      showSuccessSnackBar(context, 'Connectez-vous pour envoyer un message.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await ConversationService.sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );

      _controller.clear();
      unawaited(_markAsRead());
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _controller.value = TextEditingValue(
        text: rawDraft,
        selection: TextSelection.collapsed(offset: rawDraft.length),
      );
      showErrorSnackBar(context, 'Erreur lors de l\'envoi du message : $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _handleConversationAction(_ConversationThreadAction action) async {
    try {
      switch (action) {
        case _ConversationThreadAction.archive:
          await ConversationService.archiveConversation(conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation archivee.');
          return;
        case _ConversationThreadAction.unarchive:
          await ConversationService.unarchiveConversation(conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation restauree.');
          return;
        case _ConversationThreadAction.block:
          await ConversationService.blockConversation(conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation bloquee.');
          return;
        case _ConversationThreadAction.unblock:
          await ConversationService.unblockConversation(conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation debloquee.');
          return;
        case _ConversationThreadAction.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
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
            ),
          );
          if (confirmed != true || !mounted) return;
          await ConversationService.deleteConversation(conversationId: widget.conversationId);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Conversation supprimee.');
          Navigator.of(context).pop();
          return;
      }
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Action impossible sur cette conversation : $error');
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
          message: 'Conversation archivee pour vous. Un nouveau message la restaurera automatiquement.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kThreadBackground,
      appBar: AppBar(
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
                child: Text(_isArchivedForCurrentUser ? 'Restaurer' : 'Archiver'),
              ),
              PopupMenuItem<_ConversationThreadAction>(
                value: _isBlockedForCurrentUser
                    ? _ConversationThreadAction.unblock
                    : _ConversationThreadAction.block,
                child: Text(_isBlockedForCurrentUser ? 'Debloquer' : 'Bloquer'),
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
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      final message = _isPermissionDenied(snapshot.error)
                          ? 'Accès refusé à cette conversation.'
                          : 'Erreur de chargement des messages.';
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: kPrestoBodyTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      );
                    }

                    final liveDocs = snapshot.data?.docs ?? const [];
                    _applyInitialDraftIfNeeded(liveDocs.isNotEmpty);
                    final docs = _mergeMessageDocs(liveDocs);
                    final canLoadMore = docs.isNotEmpty &&
                      (_hasAttemptedOlderPagination
                        ? _hasMoreMessages
                        : liveDocs.length >= _messagePageSize);

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Aucun message pour le moment.\nCommencez la conversation.',
                            textAlign: TextAlign.center,
                            style: kPrestoBodyTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: docs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == docs.length) {
                          // Dernier item (visuellement en haut) : bouton charger plus
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canLoadMore)
                                TextButton.icon(
                                  onPressed: _isLoadingMoreMessages
                                      ? null
                                      : () => _loadMoreMessages(liveDocs),
                                  icon: _isLoadingMoreMessages
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.history_rounded, size: 16),
                                  label: Text(
                                    _isLoadingMoreMessages
                                        ? 'Chargement...'
                                        : 'Charger les messages plus anciens',
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF6B7280),
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }

                        final data = docs[index].data();
                        final text = (data['text'] ?? '').toString();
                        final senderId = (data['senderId'] ?? '').toString();
                        final senderName = (data['senderName'] ?? '').toString();
                        final sentAt = parseFirestoreDateTime(data['createdAt']);
                        final olderMessageDate = index + 1 < docs.length
                            ? parseFirestoreDateTime(
                                docs[index + 1].data()['createdAt'],
                              )
                            : null;
                        final showDateChip = sentAt != null &&
                            (olderMessageDate == null ||
                                !_isSameCalendarDay(sentAt, olderMessageDate));
                        final isMine = senderId == widget.currentUserId;
                        final readReceipt = isMine ? _readReceiptLabel(sentAt) : null;
                        final messageDocId = docs[index].id;

                        final messageBubble = GestureDetector(
                          onLongPress: isMine
                              ? () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Supprimer ce message'),
                                      content: const Text(
                                        'Ce message sera definitivement supprime.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: const Text('Annuler'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true || !mounted) return;
                                  try {
                                    await ConversationService.deleteMessage(
                                      conversationId: widget.conversationId,
                                      messageId: messageDocId,
                                    );
                                    if (!mounted) return;
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(content: Text('Message supprime.')),
                                    );
                                  } catch (error) {
                                    if (!mounted) return;
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Impossible de supprimer ce message : $error'),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                              decoration: BoxDecoration(
                                color: isMine ? kThreadMineColor : kThreadOtherColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                                  bottomRight: Radius.circular(isMine ? 4 : 18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
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
                                  Text(
                                    text,
                                    style: kPrestoBodyTextStyle.copyWith(
                                      color: const Color(0xFF111827),
                                      height: 1.3,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      _formatMessageTimestamp(sentAt),
                                      if (readReceipt != null) readReceipt,
                                    ].join(' · '),
                                    style: kPrestoMetaTextStyle.copyWith(
                                      fontSize: 11,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ),
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
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
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
                                color: Colors.black.withOpacity(0.06),
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
                                  ? 'Conversation bloquee'
                                  : 'Votre message...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: (_isSending || _isBlocked) ? null : _sendMessage,
                        style: FilledButton.styleFrom(
                          backgroundColor: kWhatsappGreen,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(14),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
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

enum _ConversationThreadAction {
  archive,
  unarchive,
  block,
  unblock,
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
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

String _formatMessageTimestamp(DateTime? date) {
  if (date == null) return 'Envoi...';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
