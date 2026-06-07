import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'change_email_page.dart';
import 'change_password_page.dart';
import 'delete_account_page.dart';

class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  static const routeName = '/account/security';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité du compte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.email),
              title: Text(user?.email ?? 'Email inconnu'),
              subtitle: Text(
                user?.emailVerified == true
                    ? 'Email vérifié'
                    : 'Email non vérifié',
              ),
              trailing: user?.emailVerified == true
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.warning, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.mark_email_read),
            title: const Text('Renvoyer l’email de confirmation'),
            onTap: () async {
              await AuthService.instance.resendVerificationEmail();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email de confirmation envoyé.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Changer mon email'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangeEmailPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Changer mon mot de passe'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: () => AuthService.instance.signOut(),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Supprimer mon compte'),
            textColor: Colors.red,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
