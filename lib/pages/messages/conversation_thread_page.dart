import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../utils/friendly_snackbar.dart';

const kPrestoOrange = Color(0xFFFF6600);

class ConversationThreadPage extends StatefulWidget {
  final String conversationId;
  final String offerTitle;
  final String currentUserId;

  const ConversationThreadPage({
    super.key,
    required this.conversationId,
    required this.offerTitle,
    required this.currentUserId,
  });

  @override
  State<ConversationThreadPage> createState() => _ConversationThreadPageState();
}

class _ConversationThreadPageState extends State<ConversationThreadPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  List<String> _participants = const [];

  @override
  void initState() {
    super.initState();
    _loadConversationMeta();
    _markAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversationMeta() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      final data = doc.data();
      if (data == null) return;
      final participants = (data['participants'] as List<dynamic>? ?? [])
          .map((entry) => entry.toString())
          .where((entry) => entry.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _participants = participants;
      });
    } catch (_) {}
  }

  Future<void> _markAsRead() async {
    try {
      await FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId).update({
        'unreadCount.${widget.currentUserId}': 0,
      });
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      showSuccessSnackBar(context, 'Connectez-vous pour envoyer un message.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    final convRef = FirebaseFirestore.instance.collection('conversations').doc(widget.conversationId);
    final senderName = authUser.displayName?.trim().isNotEmpty == true
        ? authUser.displayName!.trim()
        : (authUser.email ?? 'Utilisateur');

    _controller.clear();

    try {
      await convRef.collection('messages').add({
        'text': text,
        'senderId': widget.currentUserId,
        'senderName': senderName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final update = <String, dynamic>{
        'lastMessage': text,
        'lastSenderId': widget.currentUserId,
        'lastMessageAt': FieldValue.serverTimestamp(),
      };
      for (final participant in _participants) {
        if (participant == widget.currentUserId) {
          update['unreadCount.$participant'] = 0;
        } else {
          update['unreadCount.$participant'] = FieldValue.increment(1);
        }
      }
      await convRef.set(update, SetOptions(merge: true));

      await _markAsRead();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) return;
      showSuccessSnackBar(context, 'Erreur lors de l\'envoi du message : $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: Text(
          widget.offerTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kPrestoAppBarTitleStyle,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erreur de chargement des messages.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun message pour le moment.\nCommencez la conversation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final text = (data['text'] ?? '').toString();
                    final senderId = (data['senderId'] ?? '').toString();
                    final senderName = (data['senderName'] ?? '').toString();
                    final timestamp = data['createdAt'];
                    final sentAt = timestamp is Timestamp ? timestamp.toDate() : null;
                    final isMine = senderId == widget.currentUserId;

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFFFFF1E8) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMine && senderName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    senderName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              Text(
                                text,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatMessageTimestamp(sentAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Votre message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrestoOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
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
