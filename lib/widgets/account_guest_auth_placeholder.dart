import 'package:flutter/material.dart';

class AccountGuestAuthPlaceholder extends StatelessWidget {
  final String title;
  final String message;

  const AccountGuestAuthPlaceholder({
    super.key,
    this.title = 'Connexion requise',
    this.message = 'Page d\'authentification non disponible',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(message),
      ),
    );
  }
}
