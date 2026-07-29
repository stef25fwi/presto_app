import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/account_data_export_service.dart';
import '../../services/auth_service.dart';
import 'change_email_page.dart';
import 'change_password_page.dart';
import 'delete_account_page.dart';
import 'phone_verification_page.dart';
import 'package:presto_app/services/auth_guard.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  static const routeName = '/account/security';

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final AccountDataExportService _dataExportService =
      AccountDataExportService();
  bool _isExportingData = false;

  Future<void> _exportMyData() async {
    if (_isExportingData) return;
    setState(() => _isExportingData = true);
    try {
      final downloaded = await _dataExportService.exportAndDownload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Export de vos données prêt au téléchargement.'
                : 'Export annulé.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L\'export de vos données a échoué. Réessayez dans un instant.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingData = false);
    }
  }

  Future<void> _openPhoneVerification() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhoneVerificationPage()),
    );
    if (verified == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone vérifié.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6600),
        foregroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: const Color(0xFFFF6600),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Sécurité du compte'),
      ),
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
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_iphone_rounded),
              title: Text(
                (user?.phoneNumber ?? '').isNotEmpty
                    ? user!.phoneNumber!
                    : 'Aucun numéro vérifié',
              ),
              subtitle: Text(
                (user?.phoneNumber ?? '').isNotEmpty
                    ? 'Téléphone vérifié'
                    : 'Vérifie ton numéro pour sécuriser ton compte',
              ),
              trailing: (user?.phoneNumber ?? '').isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.warning, color: Colors.orange),
              onTap: _openPhoneVerification,
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
            onTap: () async {
              final allowed = await AuthGuard.requireVerifiedEmail(context);
              if (!allowed) return;
              if (!context.mounted) return;

              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangeEmailPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Changer mon mot de passe'),
            onTap: () async {
              final allowed = await AuthGuard.requireVerifiedEmail(context);
              if (!allowed) return;
              if (!context.mounted) return;

              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: _isExportingData
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            title: const Text('Exporter mes données'),
            subtitle: const Text(
              'Téléchargez une copie de vos données personnelles (profil, annonces, avis, conversations).',
            ),
            onTap: _isExportingData ? null : _exportMyData,
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
            onTap: () async {
              final allowed = await AuthGuard.requireVerifiedEmail(context);
              if (!allowed) return;
              if (!context.mounted) return;

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
