import 'package:flutter/material.dart';

import 'pages/messages/conversations_list_page.dart';

export 'pages/messages/conversations_list_page.dart';

/// Variante avec le nom buggé dans main.dart : `versationsListPage`
/// (on la garde pour ne pas casser les appels existants)
class VersationsListPage extends StatelessWidget {
  const VersationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConversationsListPage();
  }
}