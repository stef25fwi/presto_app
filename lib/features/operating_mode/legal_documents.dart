import 'app_operating_mode.dart';

class LegalDocumentSection {
  final String title;
  final String subtitle;
  final String content;

  const LegalDocumentSection({
    required this.title,
    required this.subtitle,
    required this.content,
  });
}

class LegalDocumentCatalog {
  static List<LegalDocumentSection> legalNotices(
    AppOperatingModeState state,
  ) {
    final p = state.publisher;
    final publisher = state.mode.isCommercial
        ? '${p.companyName} ${p.legalForm}'.trim()
        : p.publisherName;
    final commercialDetails = state.mode.isCommercial
        ? '''
SIREN : ${p.siren}
RCS : ${p.rcs.isEmpty ? 'non renseigné' : p.rcs}
Capital social : ${p.shareCapital.isEmpty ? 'non renseigné' : p.shareCapital}
TVA intracommunautaire : ${p.vatNumber.isEmpty ? 'non renseignée' : p.vatNumber}
'''
        : '''
Statut d'exploitation : personne physique, phase expérimentale non payante.
Ilipresto n'est pas présenté comme une société tant qu'aucune personne morale n'a été constituée.
''';

    return <LegalDocumentSection>[
      LegalDocumentSection(
        title: 'Éditeur et publication',
        subtitle: 'Identité de l’exploitant et responsable de publication.',
        content: '''
MENTIONS LÉGALES — ${state.mode.label.toUpperCase()}
Version : ${state.legalVersion}
Date d’entrée en vigueur : ${_date(state.effectiveDate)}

Nom du service : Ilipresto
Domaine : ilipresto.fr
Éditeur : $publisher
Adresse : ${p.postalAddress}
Téléphone : ${p.phone}
E-mail : ${p.email}
Directeur de la publication : ${p.publicationDirector}
$commercialDetails
Activité du service
Ilipresto est une plateforme numérique de publication et de consultation d’annonces de services, de mise en relation locale et de messagerie entre utilisateurs.

${state.mode.isCommercial ? 'La plateforme peut proposer des abonnements et services payants selon les conditions tarifaires affichées avant souscription.' : 'Pendant cette phase bêta, l’accès à la plateforme est gratuit. Aucun abonnement, paiement, commission ou moyen de paiement n’est traité par Ilipresto.'}
''',
      ),
      LegalDocumentSection(
        title: 'Hébergement',
        subtitle: 'Prestataire chargé de l’hébergement technique.',
        content: '''
HÉBERGEMENT

Hébergeur : ${p.hostingProvider}
Adresse : ${p.hostingAddress}
Service utilisé : Firebase Hosting et services Firebase nécessaires au fonctionnement de la plateforme.

Pour toute question juridique ou technique : ${p.email}
''',
      ),
      LegalDocumentSection(
        title: 'Propriété intellectuelle',
        subtitle: 'Marque, logiciel, contenus et droits des utilisateurs.',
        content: '''
PROPRIÉTÉ INTELLECTUELLE

La dénomination Ilipresto, les interfaces, textes, éléments graphiques, bases de données et composants logiciels propres à la plateforme sont protégés par les règles applicables à la propriété intellectuelle.

L’utilisateur conserve ses droits sur les contenus qu’il publie. Il accorde à l’éditeur, pour la durée de leur mise en ligne, une autorisation non exclusive strictement nécessaire à leur hébergement, leur reproduction technique, leur affichage, leur modération et leur diffusion dans la plateforme.

Toute reproduction ou extraction non autorisée de tout ou partie du service est interdite.
''',
      ),
    ];
  }

  static List<LegalDocumentSection> privacy(
    AppOperatingModeState state,
  ) {
    final p = state.publisher;
    return <LegalDocumentSection>[
      LegalDocumentSection(
        title: 'Responsable et données collectées',
        subtitle: 'Catégories de données et responsable du traitement.',
        content: '''
POLITIQUE DE CONFIDENTIALITÉ
Version : ${state.privacyVersion}
Date d’entrée en vigueur : ${_date(state.effectiveDate)}

Responsable du traitement
${state.mode.isCommercial ? '${p.companyName} ${p.legalForm}'.trim() : p.publisherName}
Adresse : ${p.postalAddress}
Contact : ${p.email}

Données susceptibles d’être traitées
• compte : adresse e-mail, téléphone, pseudonyme, nom et prénom lorsque renseignés ;
• profil : photo, zone géographique, préférences et informations professionnelles ;
• annonces : titre, description, catégorie, budget indicatif, localisation, photos et documents ;
• échanges : messages, notes audio, pièces jointes, participants et horodatages ;
• sécurité : adresse IP, journaux techniques, appareil, version de l’application et signaux antifraude ;
• notifications : jetons techniques et préférences ;
• support, signalements, modération, export et suppression de compte ;
• données d’usage et mesure d’audience lorsque la base légale requise est disponible.

${state.mode.isCommercial ? 'Lorsqu’un utilisateur souscrit, des références limitées de transaction, de statut et d’abonnement peuvent être conservées. Les coordonnées bancaires complètes sont traitées par le prestataire de paiement et ne sont pas enregistrées par Ilipresto.' : 'Aucun paiement, abonnement ou moyen de paiement n’est traité par Ilipresto pendant la bêta gratuite. Aucune donnée bancaire n’est demandée pour accéder au service.'}
''',
      ),
      const LegalDocumentSection(
        title: 'Finalités et bases légales',
        subtitle: 'Pourquoi les données sont utilisées.',
        content: '''
FINALITÉS ET BASES LÉGALES

Les données sont traitées afin de :
• créer, authentifier et sécuriser les comptes ;
• publier, afficher, rechercher et modérer les annonces ;
• permettre la messagerie et les notifications ;
• traiter les demandes de support, d’accès, d’export et de suppression ;
• prévenir la fraude, les abus et les atteintes à la sécurité ;
• améliorer le service et mesurer son utilisation dans le respect des règles relatives aux traceurs ;
• répondre aux obligations légales et aux demandes valides des autorités.

Les bases légales utilisées selon les traitements sont l’exécution des CGU, les mesures précontractuelles, le consentement, l’intérêt légitime de sécurité et d’amélioration du service, et les obligations légales.

Les traceurs non strictement nécessaires ne doivent être déposés qu’après recueil du consentement lorsqu’il est requis. Le refus n’empêche pas l’accès aux fonctions essentielles.
''',
      ),
      const LegalDocumentSection(
        title: 'Durées de conservation',
        subtitle: 'Durées définies sans valeurs provisoires.',
        content: '''
DURÉES DE CONSERVATION

• compte et profil : pendant la durée d’activité du compte, puis suppression ou anonymisation dans un délai maximal de 90 jours après validation de la demande, sauf obligation de conservation ;
• annonces actives : pendant leur publication ; annonces supprimées ou expirées : 12 mois maximum pour la sécurité, la preuve et la gestion des litiges, puis suppression ou anonymisation ;
• messages et pièces jointes : pendant la vie du compte et 24 mois maximum après la dernière activité de la conversation, sauf signalement, litige ou obligation légale ;
• journaux techniques et de sécurité : 90 jours, sauf incident nécessitant une conservation prolongée et documentée ;
• demandes de support et signalements : 3 ans à compter de leur clôture ;
• preuve d’acceptation des documents juridiques : pendant la relation puis 5 ans à compter de sa fin ;
• données de facturation en version commerciale : durée légale comptable applicable.

À l’issue de ces durées, les données sont supprimées ou rendues anonymes de manière irréversible.
''',
      ),
      LegalDocumentSection(
        title: 'Prestataires et transferts',
        subtitle: 'Firebase, e-mail, analytics et paiement selon le mode.',
        content: '''
PRESTATAIRES ET TRANSFERTS

Les données peuvent être traitées par des prestataires strictement nécessaires :
• Google/Firebase : authentification, base de données, stockage, fonctions, hébergement et notifications ;
• prestataire d’e-mail : messages transactionnels et support ;
• outils de mesure d’audience activés dans le respect du consentement applicable ;
${state.mode.isCommercial ? '• Stripe : création et gestion des abonnements et paiements lorsque l’utilisateur choisit une offre payante.' : '• aucun prestataire de paiement n’est sollicité pour l’accès à la bêta gratuite.'}

Certains prestataires peuvent traiter des données hors de l’Espace économique européen. Dans ce cas, l’éditeur s’appuie sur les mécanismes juridiques proposés par le prestataire et limite les données transmises au strict nécessaire.
''',
      ),
      LegalDocumentSection(
        title: 'Vos droits',
        subtitle: 'Accès, rectification, effacement, opposition et recours.',
        content: '''
VOS DROITS

Vous pouvez demander l’accès, la rectification, l’effacement, la limitation, l’opposition et, lorsque les conditions sont réunies, la portabilité de vos données. Vous pouvez retirer votre consentement à tout moment pour les traitements qui en dépendent.

Les demandes peuvent être créées depuis Mon profil ou envoyées à ${p.email}. Une vérification d’identité proportionnée peut être demandée en cas de doute raisonnable.

Une réponse est apportée dans le délai légal applicable. Vous pouvez également déposer une réclamation auprès de la CNIL.
''',
      ),
    ];
  }

  static List<LegalDocumentSection> terms(
    AppOperatingModeState state,
  ) {
    return <LegalDocumentSection>[
      LegalDocumentSection(
        title: 'Objet et accès au service',
        subtitle: 'Périmètre des CGU et conditions d’accès.',
        content: '''
CONDITIONS GÉNÉRALES D’UTILISATION
Version : ${state.cguVersion}
Date d’entrée en vigueur : ${_date(state.effectiveDate)}

Les présentes CGU régissent l’accès à Ilipresto, plateforme permettant de publier et consulter des annonces de services, d’échanger par messagerie et d’être mis en relation.

${state.mode.isCommercial ? 'Certaines fonctions peuvent être proposées dans le cadre d’une offre payante. Le prix, la durée, le renouvellement et les modalités de résiliation sont présentés avant toute souscription.' : 'La plateforme est proposée en bêta gratuite. Aucun abonnement, paiement ou commission n’est dû à Ilipresto. Une évolution future vers des offres payantes ne sera pas automatique : elle fera l’objet d’une information préalable, de conditions distinctes et d’une action volontaire de souscription.'}

L’utilisateur doit disposer de la capacité juridique nécessaire. Les mineurs ne peuvent utiliser le service que sous la responsabilité et avec l’autorisation de leur représentant légal.
''',
      ),
      const LegalDocumentSection(
        title: 'Comptes et sécurité',
        subtitle: 'Obligations liées au compte utilisateur.',
        content: '''
COMPTES ET SÉCURITÉ

L’utilisateur fournit des informations exactes, protège ses identifiants et signale sans délai tout accès non autorisé. Un compte ne doit pas usurper l’identité d’un tiers.

Ilipresto peut limiter, suspendre ou supprimer un compte en cas de fraude, contenu illicite, comportement dangereux, atteinte à la sécurité ou violation répétée des CGU. Une mesure proportionnée est recherchée selon la gravité et l’urgence.

L’utilisateur peut demander la suppression de son compte depuis son profil ou le support. Les conséquences sur les annonces, messages et données sont précisées dans la politique de confidentialité.
''',
      ),
      const LegalDocumentSection(
        title: 'Annonces, messages et modération',
        subtitle: 'Contenus autorisés et responsabilités.',
        content: '''
ANNONCES, MESSAGES ET MODÉRATION

L’utilisateur garantit disposer des droits nécessaires sur les contenus publiés et s’engage à respecter la loi, les droits des tiers et les règles de courtoisie.

Sont notamment interdits : contenus illégaux, frauduleux, trompeurs, haineux, discriminatoires, menaçants, harcelants, pornographiques, violents, dangereux, contrefaisants, données personnelles de tiers publiées sans droit, spam et démarchage abusif.

Ilipresto peut détecter, masquer, retirer ou soumettre à correction un contenu, et traiter les signalements manuellement ou automatiquement. La modération ne constitue pas une validation systématique de l’identité, des compétences, des assurances ou de la qualité d’un utilisateur.
''',
      ),
      const LegalDocumentSection(
        title: 'Mise en relation et prestations',
        subtitle: 'Rôle limité de la plateforme.',
        content: '''
MISE EN RELATION ET PRESTATIONS

Ilipresto fournit un outil de mise en relation. Sauf indication expresse liée à un service distinct, l’éditeur n’est ni employeur, ni mandataire, ni partie au contrat conclu entre les utilisateurs.

Les utilisateurs déterminent directement le contenu, le prix, le délai, le paiement et les conditions d’exécution de la prestation. Ils restent responsables de leurs obligations professionnelles, fiscales, sociales, administratives, d’assurance et de sécurité.

Chaque utilisateur doit vérifier les informations utiles, conserver les preuves de ses échanges, utiliser des moyens de paiement sûrs et signaler les comportements suspects.
''',
      ),
      const LegalDocumentSection(
        title: 'Disponibilité et responsabilité',
        subtitle: 'Maintenance, bêta et limites raisonnables.',
        content: '''
DISPONIBILITÉ ET RESPONSABILITÉ

Le service peut être interrompu pour maintenance, sécurité, évolution ou incident. En phase bêta, certaines fonctions peuvent être modifiées, limitées ou retirées afin d’améliorer la plateforme.

L’éditeur met en œuvre des moyens raisonnables de fonctionnement et de sécurité mais ne garantit pas une disponibilité permanente ni l’absence totale d’erreurs.

Ilipresto n’est pas responsable de la mauvaise exécution d’une prestation, d’un impayé, d’une annulation ou d’un dommage directement imputable à un utilisateur. Aucune clause ne limite les responsabilités qui ne peuvent légalement être exclues.
''',
      ),
      const LegalDocumentSection(
        title: 'Évolution des conditions',
        subtitle: 'Versions, information et nouvelle acceptation.',
        content: '''
ÉVOLUTION DES CONDITIONS

Les CGU peuvent être modifiées pour tenir compte d’une évolution fonctionnelle, juridique ou économique. La version applicable, sa date d’entrée en vigueur et son identifiant sont affichés dans la plateforme.

Une modification substantielle, notamment le passage de la bêta gratuite à une offre commerciale, peut nécessiter une nouvelle acceptation. Aucun abonnement ne sera créé sans une action volontaire de l’utilisateur.

Le droit français est applicable, sous réserve des règles impératives protectrices. Les parties recherchent d’abord une solution amiable avant toute action contentieuse.
''',
      ),
    ];
  }

  static String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
