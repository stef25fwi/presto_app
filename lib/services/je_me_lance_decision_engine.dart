enum JeMeLanceProfile {
  fonctionnaire,
  salariePrive,
  demandeurEmploi,
  etudiant,
  retraite,
  sansActivite,
  entrepreneurImmatricule,
}

enum JeMeLanceActivityType {
  restaurationSnack,
  venteMarchandises,
  prestationService,
  artisanat,
  transport,
  numerique,
  location,
  serviceDomicile,
}

enum JeMeLancePlaceType {
  domicile,
  localCommercial,
  marche,
  foodTruck,
  enLigne,
  chezClient,
}

enum JeMeLanceScale {
  test,
  secondaire,
  principale,
  developpement,
}

extension JeMeLanceProfileLabel on JeMeLanceProfile {
  String get label {
    switch (this) {
      case JeMeLanceProfile.fonctionnaire:
        return 'Fonctionnaire';
      case JeMeLanceProfile.salariePrive:
        return 'Salarié privé';
      case JeMeLanceProfile.demandeurEmploi:
        return 'Demandeur d’emploi';
      case JeMeLanceProfile.etudiant:
        return 'Étudiant';
      case JeMeLanceProfile.retraite:
        return 'Retraité';
      case JeMeLanceProfile.sansActivite:
        return 'Sans activité';
      case JeMeLanceProfile.entrepreneurImmatricule:
        return 'Entrepreneur déjà immatriculé';
    }
  }
}

extension JeMeLanceActivityTypeLabel on JeMeLanceActivityType {
  String get label {
    switch (this) {
      case JeMeLanceActivityType.restaurationSnack:
        return 'Snack / restauration rapide';
      case JeMeLanceActivityType.venteMarchandises:
        return 'Vente de marchandises';
      case JeMeLanceActivityType.prestationService:
        return 'Prestation de service';
      case JeMeLanceActivityType.artisanat:
        return 'Artisanat';
      case JeMeLanceActivityType.transport:
        return 'Transport';
      case JeMeLanceActivityType.numerique:
        return 'Numérique';
      case JeMeLanceActivityType.location:
        return 'Location';
      case JeMeLanceActivityType.serviceDomicile:
        return 'Service à domicile';
    }
  }
}

extension JeMeLancePlaceTypeLabel on JeMeLancePlaceType {
  String get label {
    switch (this) {
      case JeMeLancePlaceType.domicile:
        return 'Domicile';
      case JeMeLancePlaceType.localCommercial:
        return 'Local commercial';
      case JeMeLancePlaceType.marche:
        return 'Marché';
      case JeMeLancePlaceType.foodTruck:
        return 'Food-truck';
      case JeMeLancePlaceType.enLigne:
        return 'En ligne';
      case JeMeLancePlaceType.chezClient:
        return 'Chez le client';
    }
  }
}

extension JeMeLanceScaleLabel on JeMeLanceScale {
  String get label {
    switch (this) {
      case JeMeLanceScale.test:
        return 'Test limité';
      case JeMeLanceScale.secondaire:
        return 'Activité secondaire';
      case JeMeLanceScale.principale:
        return 'Activité principale';
      case JeMeLanceScale.developpement:
        return 'Développement / croissance';
    }
  }
}

class JeMeLanceProjectInput {
  final JeMeLanceProfile profile;
  final JeMeLanceActivityType activityType;
  final JeMeLancePlaceType placeType;
  final JeMeLanceScale scale;
  final double monthlyRevenue;
  final double monthlyCharges;
  final bool hasAssociates;
  final bool sellsAlcohol;
  final bool handlesAnimalFood;
  final bool plansEmployees;
  final bool wantsVatRecovery;
  final bool isDrom;

  const JeMeLanceProjectInput({
    required this.profile,
    required this.activityType,
    required this.placeType,
    required this.scale,
    required this.monthlyRevenue,
    required this.monthlyCharges,
    required this.hasAssociates,
    required this.sellsAlcohol,
    required this.handlesAnimalFood,
    required this.plansEmployees,
    required this.wantsVatRecovery,
    required this.isDrom,
  });

  double get annualRevenue => monthlyRevenue * 12;
  double get annualCharges => monthlyCharges * 12;
}

class JeMeLanceDecisionItem {
  final String title;
  final String detail;
  final String level;

  const JeMeLanceDecisionItem({
    required this.title,
    required this.detail,
    required this.level,
  });
}

class JeMeLanceDecisionResult {
  final String verdict;
  final String riskLevel;
  final String recommendedStatus;
  final List<JeMeLanceDecisionItem> controls;
  final List<JeMeLanceDecisionItem> statuses;
  final List<String> beforeCreation;
  final List<String> creationSteps;
  final List<String> afterSiret;
  final List<String> documents;
  final List<String> guichetUniquePreparation;

  const JeMeLanceDecisionResult({
    required this.verdict,
    required this.riskLevel,
    required this.recommendedStatus,
    required this.controls,
    required this.statuses,
    required this.beforeCreation,
    required this.creationSteps,
    required this.afterSiret,
    required this.documents,
    required this.guichetUniquePreparation,
  });
}

class JeMeLanceDecisionEngine {
  const JeMeLanceDecisionEngine();

  JeMeLanceDecisionResult evaluate(JeMeLanceProjectInput input) {
    final controls = <JeMeLanceDecisionItem>[];
    final statuses = <JeMeLanceDecisionItem>[];
    final before = <String>[];
    final creation = <String>[];
    final after = <String>[];
    final documents = <String>[];
    final guichet = <String>[];

    var risk = 'Vert';
    var verdict = 'Projet possible avec démarches classiques.';

    if (input.profile == JeMeLanceProfile.fonctionnaire) {
      risk = 'Orange';
      verdict =
          'Projet possible uniquement après vérification RH / déontologie et autorisation préalable.';
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Autorisation employeur nécessaire',
          detail:
              'Agent public : demander une autorisation écrite avant immatriculation.',
          level: 'Critique',
        ),
      );
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Risque conflit d’intérêts',
          detail:
              'Vérifier que l’activité ne perturbe pas le service et ne crée pas de prise illégale d’intérêts.',
          level: 'Critique',
        ),
      );
      before.add('Préparer une demande écrite à l’autorité hiérarchique.');
      before.add('Vérifier activité accessoire ou demande de temps partiel.');
      before.add('Attendre une réponse écrite avant immatriculation.');
      documents.add('Courrier d’autorisation hiérarchique.');
    }

    if (input.profile == JeMeLanceProfile.salariePrive) {
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Contrat de travail à vérifier',
          detail:
              'Contrôler clause d’exclusivité, non-concurrence et obligation de loyauté.',
          level: 'Important',
        ),
      );
      before.add('Relire le contrat de travail avant création.');
    }

    if (input.profile == JeMeLanceProfile.demandeurEmploi) {
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Aides emploi',
          detail: 'Comparer maintien ARE, ARCE et ACRE.',
          level: 'Important',
        ),
      );
      before.add('Contacter France Travail pour ARE / ARCE / ACRE.');
      documents.add('Justificatifs France Travail si demandeur d’emploi.');
    }

    if (input.profile == JeMeLanceProfile.entrepreneurImmatricule) {
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Modification plutôt que création',
          detail:
              'Vérifier s’il faut ajouter une activité au SIRET existant plutôt que créer une nouvelle structure.',
          level: 'Important',
        ),
      );
      creation
          .add('Préparer une modification d’activité si entreprise existante.');
    }

    if (input.activityType == JeMeLanceActivityType.restaurationSnack ||
        input.handlesAnimalFood) {
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Déclaration sanitaire',
          detail:
              'Snack ou denrées animales : prévoir déclaration sanitaire DDPP / DAAF selon région.',
          level: 'Obligatoire si concerné',
        ),
      );
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Hygiène alimentaire',
          detail:
              'Prévoir les obligations d’hygiène alimentaire et traçabilité.',
          level: 'Obligatoire',
        ),
      );
      before.add(
          'Décrire produits, stockage froid, lieu, horaires et mode de vente.');
      creation.add(
          'Faire déclaration sanitaire si denrées animales ou d’origine animale.');
      documents.add(
          'Plan de maîtrise sanitaire / justificatifs hygiène si nécessaire.');
    }

    if (input.sellsAlcohol) {
      risk = 'Orange';
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Licence / déclaration mairie',
          detail:
              'Vente d’alcool : licence adaptée et déclaration préalable en mairie.',
          level: 'Obligatoire',
        ),
      );
      before.add(
          'Identifier le type de licence nécessaire pour la vente d’alcool.');
      creation.add('Effectuer la déclaration mairie liée à la licence.');
    }

    if (input.placeType == JeMeLancePlaceType.localCommercial) {
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Local / ERP / bail',
          detail:
              'Vérifier bail commercial, accueil du public, assurance et conformité du local.',
          level: 'Important',
        ),
      );
      before
          .add('Vérifier bail, normes du local, assurance et accueil public.');
      documents
          .add('Bail, autorisation d’occupation ou justificatif du local.');
    }

    if (input.placeType == JeMeLancePlaceType.foodTruck ||
        input.placeType == JeMeLancePlaceType.marche) {
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'Occupation du domaine public',
          detail:
              'Marché ou food-truck : vérifier autorisation mairie, emplacement et assurance.',
          level: 'Important',
        ),
      );
      before.add(
          'Demander les règles d’emplacement en mairie ou auprès du gestionnaire du marché.');
    }

    if (input.annualRevenue > 85000 || input.wantsVatRecovery) {
      controls.add(
        const JeMeLanceDecisionItem(
          title: 'TVA / plafond micro',
          detail:
              'Le niveau de chiffre d’affaires ou le besoin de récupérer la TVA peut rendre le régime réel plus adapté.',
          level: 'À arbitrer',
        ),
      );
    }

    if (input.monthlyCharges > input.monthlyRevenue * 0.35 ||
        input.placeType == JeMeLancePlaceType.localCommercial ||
        input.plansEmployees ||
        input.wantsVatRecovery) {
      statuses.add(
        const JeMeLanceDecisionItem(
          title: 'EI réel / EURL / SASU',
          detail:
              'Plus adapté si charges importantes, local, salarié, TVA ou développement.',
          level: 'Recommandé',
        ),
      );
    }

    if (!input.hasAssociates &&
        input.monthlyCharges <= input.monthlyRevenue * 0.35 &&
        !input.plansEmployees &&
        !input.wantsVatRecovery) {
      statuses.add(
        const JeMeLanceDecisionItem(
          title: 'Micro-entreprise',
          detail:
              'Adaptée pour tester une activité simple avec peu de charges.',
          level: 'Possible',
        ),
      );
    }

    if (input.hasAssociates) {
      statuses.add(
        const JeMeLanceDecisionItem(
          title: 'SARL / SAS',
          detail:
              'Associés présents : préférer une société avec répartition des parts et statuts.',
          level: 'Recommandé',
        ),
      );
    }

    if (input.activityType == JeMeLanceActivityType.serviceDomicile) {
      statuses.add(
        const JeMeLanceDecisionItem(
          title: 'Micro / EI / société',
          detail:
              'À choisir selon volume, charges, agrément éventuel et clientèle.',
          level: 'À comparer',
        ),
      );
    }

    if (statuses.isEmpty) {
      statuses.add(
        const JeMeLanceDecisionItem(
          title: 'Micro-entreprise ou EI',
          detail:
              'Statut simple à comparer avec EI réel selon chiffre d’affaires et charges.',
          level: 'À comparer',
        ),
      );
    }

    final recommendedStatus = statuses.first.title;

    creation.add('Créer ou modifier l’entreprise via le Guichet unique INPI.');
    creation.add('Choisir les options fiscales et sociales adaptées.');
    creation
        .add('Comparer le statut avec la simulation Mon-entreprise / Urssaf.');
    after.add(
        'Mettre en place facturation, livre des recettes et suivi des charges.');
    after.add('Déclarer le chiffre d’affaires selon le régime choisi.');
    after.add('Souscrire RC pro et assurances utiles.');
    documents.add('Pièce d’identité.');
    documents.add('Justificatif de domicile ou local.');
    documents.add('Description de l’activité.');
    documents.add('Estimation chiffre d’affaires / charges.');
    documents.add('Checklist des démarches avant création.');

    guichet.add('Type d’entreprise : micro, EI, EURL, SASU, SARL ou SAS.');
    guichet.add('Identité du déclarant et adresse de l’établissement.');
    guichet.add('Description de l’activité principale et secondaire.');
    guichet.add('Options fiscales et sociales.');
    guichet.add('Pièces justificatives à préparer avant dépôt.');
    guichet.add('Dépôt final à réaliser sur formalites.entreprises.gouv.fr.');

    if (input.profile == JeMeLanceProfile.fonctionnaire &&
        (input.activityType == JeMeLanceActivityType.restaurationSnack ||
            input.placeType == JeMeLancePlaceType.localCommercial)) {
      risk = 'Orange / Rouge';
      verdict =
          'Feu orange : snack possible seulement après validation employeur public et contrôle déontologique.';
    }

    return JeMeLanceDecisionResult(
      verdict: verdict,
      riskLevel: risk,
      recommendedStatus: recommendedStatus,
      controls: controls,
      statuses: statuses,
      beforeCreation: before,
      creationSteps: creation,
      afterSiret: after,
      documents: documents,
      guichetUniquePreparation: guichet,
    );
  }
}
