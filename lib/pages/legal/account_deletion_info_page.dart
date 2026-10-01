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
                            '4. Confirmez votre identité : mot de passe ou '
                            'réauthentification Google, Apple ou Facebook.\n'
                            '5. Tapez SUPPRIMER et confirmez la suppression '
                            'définitive.\n\n'
                            'Pour un compte Apple, iliprestō révoque également '
                            'le jeton Sign in with Apple avant l’effacement. '
                            'L’effacement actif est déclenché immédiatement '
                            'après confirmation.',
                      ),
                      const SizedBox(height: 12),
                      _Card(
                        title: 'Sans passer par l’application',
                        icon: Icons.mail_outline_rounded,
                        body: email.isEmpty
                            ? 'Écrivez à l’adresse de contact indiquée dans les '
                                'mentions légales, depuis l’adresse e-mail du '
                                'compte, avec pour objet « Suppression de '
                                'compte ». Une vérification d’identité '
                                'proportionnée peut être demandée. La demande '
                                'est traitée dans les meilleurs délais et au '
                                'plus tard dans le délai légal applicable.'
                            : 'Écrivez à $email depuis l’adresse e-mail du '
                                'compte, avec pour objet « Suppression de '
                                'compte ». Nous vérifions que la demande '
                                'provient bien du titulaire lorsque cela est '
                                'nécessaire, puis la traitons dans les meilleurs '
                                'délais et au plus tard dans le délai légal '
                                'applicable.',
                        actionLabel: email.isEmpty ? null : 'Écrire à $email',
                        onAction: email.isEmpty
                            ? null
                            : () => launchUrl(
                                  Uri(
                                    scheme: 'mailto',
                                    path: email,
                                    queryParameters: const <String, String>{
                                      'subject':
                                          'Suppression de compte iliprestō',
                                    },
                                  ),
                                ),
                      ),
                      const SizedBox(height: 12),
                      const _Card(
                        title: 'Données supprimées ou désassociées',
                        icon: Icons.delete_outline_rounded,
                        body:
                            '• Le compte Firebase Authentication et ses moyens '
                            'de connexion.\n'
                            '• Le profil : nom, photo, téléphone, ville, code '
                            'postal et préférences.\n'
                            '• Les données de vérification téléphone et SIRET '
                            'qui ne doivent pas être conservées pour un motif '
                            'légal ou de sécurité.\n'
                            '• Les photos et fichiers des annonces, brouillons '
                            'et pièces jointes.\n'
                            '• Les avis liés au compte.\n'
                            '• Les messages envoyés par le compte dans les '
                            'conversations actives ; la conversation est '
                            'anonymisée pour les autres participants.\n'
                            '• Les enregistrements audio temporaires.\n'
                            '• Les jetons et préférences de notification.',
                      ),
                      const SizedBox(height: 12),
                      const _Card(
                        title: 'Données pouvant être conservées',
                        icon: Icons.schedule_rounded,
                        body:
                            'Une conservation résiduelle n’est possible que '
                            'pour une finalité déterminée : obligation légale, '
                            'sécurité, prévention de la fraude, modération ou '
                            'gestion d’un litige. L’accès est alors limité et '
                            'les données sont supprimées ou anonymisées à '
                            'l’issue de la durée prévue.\n\n'
                            '• Journaux techniques courants et notifications : '
                            'jusqu’à 90 jours.\n'
                            '• Journaux d’envoi d’e-mails : jusqu’à 180 jours.\n'
                            '• Journaux de sécurité, modération et '
                            'administration : jusqu’à 12 mois, sauf incident '
                            'ou contentieux documenté.\n'
                            '• Métadonnées minimales d’une annonce retirée : '
                            'jusqu’à 12 mois pour la preuve et les litiges ; '
                            'les fichiers publiés sont supprimés.\n'
                            '• Demandes de support et signalements : jusqu’à '
                            '3 ans après clôture lorsqu’une conservation est '
                            'nécessaire à la preuve ou au suivi.\n'
                            '• Pièces comptables et factures, lorsqu’il en '
                            'existe : 10 ans.\n'
                            '• Statistiques irréversiblement anonymisées : '
                            'elles peuvent subsister car elles ne permettent '
                            'plus d’identifier un utilisateur.\n\n'
                            'Les messages écrits par les autres participants '
                            'restent dans leur conversation. Les messages '
                            'envoyés par le compte supprimé sont retirés du '
                            'parcours actif.',
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
                        'Ce bouton ouvre le parcours authentifié de suppression. '
                        'Si vous n’avez plus accès à l’application, utilisez '
                        'directement la demande par e-mail ci-dessus.',
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
