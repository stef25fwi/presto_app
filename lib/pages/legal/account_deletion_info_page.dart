import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../features/operating_mode/app_operating_mode.dart';
import '../account/delete_account_page.dart';

/// Page publique décrivant la suppression d'un compte iliprestō.
///
/// Elle répond à l'obligation Google Play « Suppression des données » : l'URL
/// doit être consultable sans installer l'application et sans être connecté,
/// et décrire à la fois la suppression depuis l'application et la demande
/// hors application. Elle ne supprime rien par elle-même — le parcours
/// authentifié reste [DeleteAccountPage].
class AccountDeletionInfoPage extends StatelessWidget {
  const AccountDeletionInfoPage({
    super.key,
    this.operatingModeService,
  });

  static const String routeName = '/suppression-compte';

  final AppOperatingModeService? operatingModeService;

  static const Color _orange = Color(0xFFFF6600);
  static const Color _background = Color(0xFFF7F8FA);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  Stream<AppOperatingModeState> _stateStream() {
    try {
      return (operatingModeService ?? AppOperatingModeService())
          .watchPublicState();
    } catch (_) {
      return Stream<AppOperatingModeState>.value(
        AppOperatingModeState.defaults(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('iliprestō', style: kPrestoAppBarTitleStyle),
      ),
      body: StreamBuilder<AppOperatingModeState>(
        stream: _stateStream(),
        builder: (context, snapshot) {
          final state = snapshot.data ?? AppOperatingModeState.defaults();
          final email = state.publisher.email.trim();
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supprimer votre compte iliprestō',
                        style: TextStyle(
                          color: _text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Application concernée : iliprestō (fr.ilipresto.app). '
                        'La suppression est définitive et gratuite.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _Card(
                        title: 'Depuis l’application',
                        icon: Icons.phone_iphone_rounded,
                        body:
                            '1. Ouvrez iliprestō et connectez-vous.\n'
                            '2. Allez dans Compte, puis Sécurité du compte.\n'
                            '3. Choisissez Supprimer mon compte.\n'
                            '4. Confirmez votre identité (mot de passe, ou '
                            'reconnexion Google ou Apple).\n\n'
                            'La demande est enregistrée immédiatement après '
                            'confirmation.',
                      ),
                      const SizedBox(height: 12),
                      _Card(
                        title: 'Sans passer par l’application',
                        icon: Icons.mail_outline_rounded,
                        body: email.isEmpty
                            ? 'Écrivez à l’adresse de contact indiquée dans les '
                                'mentions légales, depuis l’adresse e-mail du '
                                'compte, avec pour objet « Suppression de '
                                'compte ». La demande est traitée dans un délai '
                                'de 30 jours.'
                            : 'Écrivez à $email depuis l’adresse e-mail du '
                                'compte, avec pour objet « Suppression de '
                                'compte ». Nous vérifions que la demande '
                                'provient bien du titulaire, puis la traitons '
                                'dans un délai de 30 jours.',
                        actionLabel: email.isEmpty ? null : 'Écrire à $email',
                        onAction: email.isEmpty
                            ? null
                            : () => launchUrl(
                                  Uri(
                                    scheme: 'mailto',
                                    path: email,
                                    queryParameters: const <String, String>{
                                      'subject': 'Suppression de compte',
                                    },
                                  ),
                                ),
                      ),
                      const SizedBox(height: 12),
                      const _Card(
                        title: 'Données supprimées',
                        icon: Icons.delete_outline_rounded,
                        body:
                            '• Le compte d’authentification et ses moyens de '
                            'connexion.\n'
                            '• Le profil : nom, photo, téléphone, ville et code '
                            'postal, préférences.\n'
                            '• Les annonces publiées et leurs photos.\n'
                            '• Les conversations et les messages envoyés.\n'
                            '• Les enregistrements audio et les documents '
                            'téléversés.\n'
                            '• Les jetons de notification de vos appareils.',
                      ),
                      const SizedBox(height: 12),
                      const _Card(
                        title: 'Données conservées après suppression',
                        icon: Icons.schedule_rounded,
                        body:
                            'Certaines données sont conservées le temps imposé '
                            'par nos obligations légales ou par la sécurité du '
                            'service, puis supprimées :\n\n'
                            '• Journaux techniques et de notification : 90 '
                            'jours.\n'
                            '• Journaux d’envoi d’e-mails : 180 jours.\n'
                            '• Journaux de modération et d’administration : 1 '
                            'an.\n'
                            '• Annonces retirées, à des fins de preuve en cas '
                            'de litige : 1 an.\n'
                            '• Pièces comptables et factures, lorsqu’il en '
                            'existe : 10 ans.\n\n'
                            'Les messages déjà reçus par vos correspondants '
                            'restent visibles dans leur propre boîte, sans '
                            'votre profil.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pushNamed(
                          DeleteAccountPage.routeName,
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Supprimer mon compte maintenant'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ce bouton demande une connexion : il ouvre le parcours '
                        'de suppression dans l’application.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Card({
    required this.title,
    required this.body,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AccountDeletionInfoPage._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AccountDeletionInfoPage._orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AccountDeletionInfoPage._text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            body,
            style: const TextStyle(
              color: AccountDeletionInfoPage._text,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.mail_outline_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
