import 'package:flutter/material.dart';

/// Liste des conversations (placeholder)
class ConversationsListPage extends StatelessWidget {
  const ConversationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes messages'),
      ),
      body: const Center(
        child: Text(
          'La messagerie sera disponible dans une prochaine version de Prest\'o 🙂',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Variante avec le nom buggé dans main.dart : `versationsListPage`
/// (on la garde pour ne pas casser les appels existants)
class VersationsListPage extends StatelessWidget {
  const VersationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConversationsListPage();
  }
}

/// Page de conversation (placeholder)
class ConversationPage extends StatelessWidget {
  final String? conversationId;

  const ConversationPage({super.key, this.conversationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie Prest\'o'),
      ),
      body: const Center(
        child: Text(
          'La messagerie sera disponible dans une prochaine version de Prest\'o 🙂',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}