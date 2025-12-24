import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalInfoPage extends StatefulWidget {
  const LegalInfoPage({super.key});

  @override
  State<LegalInfoPage> createState() => _LegalInfoPageState();
}

class _LegalInfoPageState extends State<LegalInfoPage> {
  static const Color kOrange = Color(0xFFFF6600);
  static const Color kBg = Color(0xFFFFFFFF);

  int _tab = 0; // 0=Mentions, 1=Confidentialité, 2=CGU

  String _formatDateFr(DateTime d) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _openSection({
    required String title,
    required String content,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LegalSectionPage(
          title: title,
          content: content,
          orange: kOrange,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          "iliprestō",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _SegmentTabs(
                activeIndex: _tab,
                labels: const ["Mentions légales", "Confidentialité", "CGU"],
                onChanged: (i) => setState(() => _tab = i),
                orange: kOrange,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    ..._buildTabContent(),
                    const SizedBox(height: 12),
                    _QuestionCard(
                      orange: kOrange,
                      email: "contact@ilipresto.fr",
                      onTapEmail: () {
                        _launchUrl(Uri.parse('mailto:contact@ilipresto.fr'));
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: null,
    );
  }

  List<Widget> _buildTabContent() {
    switch (_tab) {
      case 0:
        return [
          _InfoTileCard(
            title: "À propos de nous",
            subtitle: "Informations sur la société derrière iliprestō.",
            onTap: () => _openSection(
              title: "À propos de nous",
              content: """
À propos de nous

Éditeur du site / de l'application
iliprestō

Éditeur : [Nom Prénom], Auto-entrepreneur
Adresse : [Adresse complète]
SIRET : [N° SIRET]
Email : contact@ilipresto.fr
Téléphone : [Optionnel]

Activité
Plateforme de mise en relation locale permettant la publication et la consultation d'annonces de services, ainsi que l'échange entre utilisateurs via une messagerie.
""",
            ),
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Responsable de publication",
            subtitle: "Coordonnées du responsable de la publication.",
            onTap: () => _openSection(
              title: "Responsable de publication",
              content: """
Responsable de publication

Responsable de la publication
[Nom Prénom] – Auto-entrepreneur

Contact : contact@ilipresto.fr
Adresse : [Adresse complète]
""",
            ),
          ),
          const SizedBox(height: 12),
          _HostingCard(
            orange: kOrange,
            onTap: () => _openSection(
              title: "Hébergement",
              content: """
Hébergement

Hébergeur
Google Ireland Limited (Firebase Hosting)
Gordon House, Barrow Street
Dublin 4, Irlande

Service : Firebase Hosting
""",
            ),
            onDownloadPdf: () {
              _launchUrl(Uri.parse('https://ilipresto.fr/mentions-legales.pdf'));
            },
            lastUpdateText: "Dernière mise à jour : ${_formatDateFr(DateTime.now())}",
          ),
        ];

      case 1:
        return [
          _InfoTileCard(
            title: "Données collectées",
            subtitle: "Quelles données nous collectons et pourquoi.",
            onTap: () => _openSection(
              title: "Données collectées",
              content: """
Politique de confidentialité – Données collectées

1. Qui est le responsable du traitement ?
Le responsable du traitement est iliprestō, exploité par [Nom Prénom], Auto-entrepreneur, joignable à l'adresse contact@ilipresto.fr.

2. Données que nous pouvons collecter
Selon l'utilisation que vous faites de la Plateforme, nous pouvons collecter les catégories de données suivantes :

a) Données de compte
• Adresse e-mail
• Numéro de téléphone
• Nom / prénom ou pseudonyme (si renseigné)
• Photo de profil (si ajoutée)
• Ville / zone de recherche (si renseignée)

b) Données liées aux annonces
• Titre, description, catégorie / sous-catégorie
• Budget indicatif (si renseigné)
• Localisation liée à l'annonce (ville/zone)
• Photos et contenus que vous ajoutez à vos annonces

c) Données liées aux échanges
• Messages échangés via la messagerie interne
• Métadonnées techniques (horodatage, participants, statut de livraison/lecture)

d) Données techniques et de sécurité
• Adresse IP (sécurité, prévention des abus)
• Données de connexion et journaux techniques (logs)
• Informations techniques sur l'appareil et la version de l'application (diagnostic et amélioration)

e) Notifications
• Jeton de notification (ex. Firebase Cloud Messaging) pour vous envoyer des notifications (si vous les activez).

3. Données sensibles
La Plateforme n'a pas vocation à collecter des données dites "sensibles" (santé, opinions, etc.). Nous vous invitons à ne pas publier de telles informations dans vos annonces ou messages.

4. Origine des données
Les données proviennent :
• de vous (création de compte, annonces, messages)
• de votre appareil (données techniques)
• de services techniques nécessaires au fonctionnement (ex. Firebase)
""",
            ),
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Durée de conservation",
            subtitle: "Combien de temps nous gardons vos données.",
            onTap: () => _openSection(
              title: "Durée de conservation",
              content: """
Politique de confidentialité – Durée de conservation

Nous conservons vos données uniquement pendant la durée nécessaire aux finalités décrites (fourniture du service, sécurité, obligations légales), puis nous les supprimons ou les anonymisons.

1. Compte utilisateur
• Données de compte : conservées tant que le compte est actif.
• En cas de suppression du compte, certaines données peuvent être conservées pendant une durée limitée pour gérer les obligations légales, la sécurité, ou la résolution de litiges (ex. prévention de fraude), puis supprimées.

2. Annonces
• Données d'annonces : conservées tant que l'annonce est en ligne.
• Après suppression/expiration : archivage éventuel pendant [ex. 12 mois] (à ajuster), puis suppression/anonymisation.

3. Messagerie
• Messages : conservés tant que nécessaire au fonctionnement du service et à la gestion des échanges.
• En cas de suppression du compte : suppression/archivage pendant [ex. 24 mois] (à ajuster), puis suppression/anonymisation.

4. Données techniques (logs)
• Logs techniques et sécurité : conservés généralement [ex. 30 à 90 jours] (à ajuster), sauf nécessité liée à un incident de sécurité ou à une obligation légale.

5. Obligations légales
Certaines données peuvent être conservées plus longtemps lorsque la loi l'impose (par exemple en cas de demande d'une autorité compétente) ou pour l'exercice/la défense de droits en justice.
""",
            ),
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Vos droits (RGPD)",
            subtitle: "Accès, rectification, suppression, opposition…",
            onTap: () => _openSection(
              title: "Vos droits (RGPD)",
              content: """
Politique de confidentialité – Vos droits (RGPD)

Conformément au Règlement Général sur la Protection des Données (RGPD) et à la réglementation française, vous disposez des droits suivants :

1. Vos droits
• Droit d’accès : obtenir la confirmation que des données vous concernant sont traitées et en obtenir une copie
• Droit de rectification : corriger des données inexactes ou incomplètes
• Droit à l’effacement : demander la suppression de vos données (dans les limites légales)
• Droit d’opposition : vous opposer à certains traitements, notamment lorsqu’ils reposent sur l’intérêt légitime
• Droit à la limitation : demander la suspension temporaire d’un traitement dans certains cas
• Droit à la portabilité : récupérer certaines données dans un format structuré, couramment utilisé
• Droit de retirer votre consentement : lorsque le traitement est basé sur votre consentement (ex. notifications, localisation précise si utilisée)

2. Comment exercer vos droits ?
Vous pouvez exercer vos droits en écrivant à : contact@ilipresto.fr
Afin de traiter votre demande, nous pouvons être amenés à vérifier votre identité en cas de doute raisonnable (par exemple pour éviter une usurpation).

3. Délais de réponse
Nous répondons dans les délais prévus par la réglementation (en principe 1 mois, prolongeable dans certains cas).

4. Réclamation
Si vous estimez, après nous avoir contactés, que vos droits ne sont pas respectés, vous pouvez déposer une réclamation auprès de l’autorité de contrôle compétente : la CNIL.
""",
            ),
          ),
        ];

      case 2:
        return [
          _InfoTileCard(
            title: "Objet des CGU",
            subtitle: "Règles d'utilisation de la plateforme.",
            onTap: () {
              final now = DateTime.now();
              final d = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
              _openSection(
                title: "Objet des CGU",
                content: """
Conditions Générales d’Utilisation (CGU) – Objet

Les présentes Conditions Générales d’Utilisation (ci-après « CGU ») ont pour objet de définir les règles d’accès et d’utilisation de la plateforme iliprestō (ci-après « la Plateforme »), accessible via une application mobile et/ou un site web, permettant notamment :
• la publication d’annonces de services par des utilisateurs (ci-après « Annonceurs »),
• la consultation et la réponse à ces annonces par d’autres utilisateurs (ci-après « Prestataires »),
• la mise en relation et l’échange via une messagerie interne.

Acceptation des CGU
En créant un compte, en naviguant sur la Plateforme ou en utilisant ses fonctionnalités, l’utilisateur reconnaît avoir pris connaissance des CGU et les accepter sans réserve.

Éditeur
La Plateforme est exploitée par [Nom Prénom], Auto-entrepreneur, contact : contact@ilipresto.fr (ci-après « l’Éditeur »).

Nature du service / absence d’intermédiation contractuelle
La Plateforme est un service de mise en relation. L’Éditeur n’est pas partie aux accords, prestations, devis, contrats, paiements ou litiges pouvant intervenir entre Annonceur et Prestataire.
Chaque utilisateur demeure seul responsable des engagements qu’il prend et de la conformité légale de son activité.

Accès au service
L’accès peut nécessiter une connexion internet et un appareil compatible. L’Éditeur peut faire évoluer, suspendre ou limiter certaines fonctionnalités (maintenance, sécurité, mise à jour, incident), sans que cela n’ouvre droit à indemnisation.

Modification des CGU
Les CGU peuvent être mises à jour. La version applicable est celle accessible dans l’application/site au moment de l’utilisation.
Dernière mise à jour : $d.
""",
              );
            },
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Comptes & sécurité",
            subtitle: "Création de compte, responsabilités, accès.",
            onTap: () => _openSection(
              title: "Comptes & sécurité",
              content: """
CGU – Comptes & sécurité

1. Création de compte
Certaines fonctionnalités (publication, messagerie, réponses) nécessitent la création d’un compte. L’utilisateur s’engage à fournir des informations exactes, à jour et à ne pas usurper l’identité d’un tiers.

2. Responsabilité de l’utilisateur
L’utilisateur est responsable :
• de la confidentialité de ses identifiants,
• de l’usage de son compte,
• des actions réalisées via son compte, y compris en cas de perte/vol si aucune mesure n’a été prise (changement de mot de passe, déconnexion, etc.).

En cas de suspicion d’accès non autorisé, l’utilisateur doit contacter l’Éditeur à contact@ilipresto.fr dans les meilleurs délais.

3. Sécurité et lutte contre les abus
Afin de protéger la Plateforme et les utilisateurs, l’Éditeur peut mettre en place des mesures de sécurité (contrôles, limitation, détection d’abus, modération, blocage, etc.).
Toute tentative de fraude, contournement, intrusion, extraction automatisée des données (scraping), ou attaque contre la Plateforme est strictement interdite.

4. Suspension / suppression de compte
L’Éditeur se réserve le droit de suspendre ou supprimer un compte, sans préavis, en cas notamment :
• de non-respect des CGU,
• de comportement abusif, illégal ou dangereux,
• de contenus manifestement illicites,
• de fraude ou tentative de fraude,
• de risque pour la sécurité de la Plateforme ou des utilisateurs.

5. Suppression par l’utilisateur
L’utilisateur peut demander la suppression de son compte selon les modalités prévues dans la politique de confidentialité. Certaines données peuvent être conservées pour des obligations légales, la sécurité ou la gestion des litiges.

6. Notifications
L’utilisateur peut recevoir des notifications (messages, réponses, informations importantes). Il peut les désactiver via les réglages de son appareil ou de l’application, sous réserve des notifications strictement nécessaires au fonctionnement et à la sécurité.
""",
            ),
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Publication d'annonces",
            subtitle: "Contenus autorisés, modération, signalements.",
            onTap: () => _openSection(
              title: "Publication d'annonces",
              content: """
CGU – Publication d’annonces, contenus et modération

1. Règles générales
En publiant une annonce ou tout contenu (texte, photo, message), l’utilisateur garantit :
• être titulaire des droits sur les contenus ou disposer des autorisations nécessaires,
• ne pas publier de contenu trompeur, mensonger ou de nature à induire en erreur,
• respecter la loi, l’ordre public, et les droits des tiers.

2. Contenus interdits (liste indicative)
Sont notamment interdits :
• annonces illégales (stupéfiants, contrefaçons, armes, etc.),
• contenus haineux, discriminatoires, diffamatoires, menaçants, harcelants,
• contenus à caractère sexuel explicite / pornographique,
• contenus incitant à la violence, à la fraude, à des pratiques dangereuses,
• tentatives d’arnaque (faux profils, faux paiements, phishing, demandes d’infos bancaires),
• spam, publicité non autorisée, démarchage agressif,
• divulgation de données personnelles d’un tiers sans consentement,
• contenu portant atteinte aux droits de propriété intellectuelle.

3. Qualité et clarté des annonces
L’utilisateur s’engage à publier une annonce claire, utile et suffisamment détaillée (besoin, lieu/zone, budget indicatif si possible, contraintes éventuelles).
L’Éditeur peut limiter certains formats ou refuser des annonces manifestement incomplètes ou contraires à l’objectif du service.

4. Modération / retrait de contenu
L’Éditeur peut, à tout moment et sans obligation de justification :
• masquer, retirer ou désactiver une annonce,
• demander une correction,
• limiter la visibilité,
• suspendre le compte en cas d’abus répété.

La modération peut être effectuée automatiquement ou manuellement, notamment suite à un signalement.

5. Signalement
Les utilisateurs peuvent signaler un contenu ou un comportement inapproprié via [fonction de signalement] ou par email : contact@ilipresto.fr.
L’Éditeur se réserve le droit de demander des informations complémentaires et de prendre les mesures appropriées.

6. Mise en relation et précautions
La Plateforme ne vérifie pas systématiquement l’identité, les compétences, assurances ou autorisations des utilisateurs.
Il appartient à chaque utilisateur de prendre les précautions nécessaires avant toute prestation :
• vérifier les informations,
• convenir clairement du prix, des modalités, du délai,
• ne jamais communiquer d’informations bancaires sensibles,
• privilégier des moyens de paiement sûrs,
• signaler tout comportement suspect.

7. Responsabilité liée aux prestations
Les utilisateurs restent seuls responsables :
• de l’exécution de la prestation,
• de la conformité aux lois (déclarations, obligations professionnelles, assurances),
• des dommages causés dans le cadre d’une prestation.

L’Éditeur ne pourra être tenu responsable des litiges, retards, annulations, défauts de prestation, impayés, ou dommages intervenus entre utilisateurs.
""",
            ),
          ),
        ];

      default:
        return [];
    }
  }
}

class _LegalSectionPage extends StatelessWidget {
  final String title;
  final String content;
  final Color orange;

  const _LegalSectionPage({
    required this.title,
    required this.content,
    required this.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ fond blanc
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.6,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                content.trim(),
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFF2B2623),
                ),
              ),
              const SizedBox(height: 16),
              if (title == "Vos droits (RGPD)")
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      _launchUrl(Uri.parse('https://www.cnil.fr/fr/plaintes'));
                    },
                    icon: Icon(Icons.open_in_new_rounded, color: orange),
                    label: Text(
                      "Déposer une réclamation auprès de la CNIL",
                      style: TextStyle(color: orange, fontWeight: FontWeight.w700),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  final int activeIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  final Color orange;

  const _SegmentTabs({
    required this.activeIndex,
    required this.labels,
    required this.onChanged,
    required this.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E1DC)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == activeIndex;
          return Expanded(
            child: InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (i != activeIndex) onChanged(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? orange.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? orange : Colors.transparent,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isActive ? orange : const Color(0xFF8A817B),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _InfoTileCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _InfoTileCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF7C7772)),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 28),
        onTap: onTap,
      ),
    );
  }
}

class _HostingCard extends StatelessWidget {
  final Color orange;
  final VoidCallback onTap;
  final VoidCallback onDownloadPdf;
  final String lastUpdateText;

  const _HostingCard({
    required this.orange,
    required this.onTap,
    required this.onDownloadPdf,
    required this.lastUpdateText,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Row(
                children: const [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hébergement",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Détails sur l'hébergeur du site.",
                          style: TextStyle(color: Color(0xFF7C7772)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onDownloadPdf,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD6BF)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_rounded, color: orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Télécharger nos mentions légales (PDF)",
                        style: TextStyle(
                          color: const Color(0xFF4A3F39),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                lastUpdateText,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A817B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Color orange;
  final String email;
  final VoidCallback onTapEmail;

  const _QuestionCard({
    required this.orange,
    required this.email,
    required this.onTapEmail,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Vous avez une question ?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              "Contactez-nous à l'adresse suivante :",
              style: TextStyle(color: Color(0xFF7C7772)),
            ),
            const SizedBox(height: 12),
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTapEmail,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7F2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE6E1DC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_rounded, color: orange, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        email,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3A332F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

Future<void> _launchUrl(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
