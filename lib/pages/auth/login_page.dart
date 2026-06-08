import 'package:flutter/material.dart';

import '../account_page.dart';

/// Compatibilité ancienne route /login.
///
/// L'ancien écran LoginPage avec header blanc n'est plus utilisé.
/// Toutes les demandes de connexion passent par AccountPage,
/// qui affiche SignedOutAccountFallback quand l'utilisateur est déconnecté.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  Widget build(BuildContext context) {
    return const AccountPage();
  }
}
