import 'package:flutter/material.dart';

/// On redéfinit juste la couleur orange Prestō ici
const kPrestoOrange = Color(0xFFFF6600);

/// Page liste des conversations (version simple, juste pour débloquer la compilation)
class ConversationsListPage extends StatelessWidget {
  const ConversationsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        title: const Text(
          "Mes messages",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: const Center(
        child: Text(
          "Messagerie Prestō : bientôt disponible",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}