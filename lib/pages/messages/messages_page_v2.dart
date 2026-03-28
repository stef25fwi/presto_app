import 'package:flutter/material.dart';

import 'conversations_list_page.dart';

class MessagesPageV2 extends StatelessWidget {
  final String? initialConversationId;
  final String? initialDraftText;

  const MessagesPageV2({
    super.key,
    this.initialConversationId,
    this.initialDraftText,
  });

  @override
  Widget build(BuildContext context) {
    return ConversationsListPage(
      initialConversationId: initialConversationId,
      initialDraftText: initialDraftText,
      appBarTitle: 'Mes messages 2',
    );
  }
}