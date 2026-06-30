class JeMeLanceRegionContact {
  final String category;
  final String name;
  final String role;
  final String action;

  const JeMeLanceRegionContact({
    required this.category,
    required this.name,
    required this.role,
    required this.action,
  });
}

class JeMeLanceRegionData {
  final String code;
  final String name;
  final List<JeMeLanceRegionContact> contacts;
  final List<String> aides;
  final List<String> vigilance;

  const JeMeLanceRegionData({
    required this.code,
    required this.name,
    required this.contacts,
    required this.aides,
    required this.vigilance,
  });
}

List<JeMeLanceRegionContact> _standardContacts(String regionName) {
  return [
    JeMeLanceRegionContact(
      category: 'Commerce',
      name: 'CCI $regionName',
      role:
          'Accompagnement commerce, services, snack, boutique, formalités et réseau local.',
      action:
          'Préparer un rendez-vous avec description du projet, budget et lieu prévu.',
    ),
    JeMeLanceRegionContact(
      category: 'Artisanat',
      name: 'CMA $regionName',
      role:
          'Accompagnement si activité artisanale, fabrication, transformation ou métier manuel.',
      action: 'Vérifier si l’activité dépend aussi de la Chambre de Métiers.',
    ),
    JeMeLanceRegionContact(
      category: 'Social',
      name: 'Urssaf $regionName',
      role:
          'Cotisations sociales, micro-entreprise, déclarations de chiffre d’affaires.',
      action: 'Comparer le statut avec la simulation Mon-entreprise.',
    ),
    JeMeLanceRegionContact(
      category: 'Emploi',
      name: 'France Travail $regionName',
      role: 'ARE, ARCE, ACRE et accompagnement du créateur demandeur d’emploi.',
      action: 'À vérifier si le porteur de projet est demandeur d’emploi.',
    ),
    JeMeLanceRegionContact(
      category: 'Collectivité',
      name: 'Région $regionName',
      role: 'Aides économiques, dispositifs régionaux et accompagnement local.',
      action: 'Vérifier les aides ouvertes selon la commune et le secteur.',
    ),
  ];
}

List<JeMeLanceRegionContact> _domContacts(String regionName) {
  return [
    ..._standardContacts(regionName),
    JeMeLanceRegionContact(
      category: 'Alimentaire',
      name: 'DAAF $regionName',
      role:
          'Déclaration sanitaire pour les denrées animales ou d’origine animale.',
      action:
          'À vérifier avant ouverture pour snack, restauration, vente alimentaire ou transformation.',
    ),
    JeMeLanceRegionContact(
      category: 'Travail / réglementation',
      name: 'DEETS $regionName',
      role:
          'Information travail, emploi, activité indépendante et réglementation locale.',
      action:
          'À consulter si embauche, activité secondaire ou doute réglementaire.',
    ),
  ];
}

const List<String> _standardAides = [
  'ACRE selon éligibilité.',
  'ARCE ou maintien ARE si demandeur d’emploi.',
  'Accompagnement CCI / CMA.',
  'Aides régionales selon secteur, commune et calendrier.',
  'Prêt d’honneur ou réseau Initiative / BGE selon disponibilité locale.',
];

const List<String> _standardVigilance = [
  'Vérifier si l’activité est réglementée.',
  'Vérifier les plafonds micro, la TVA et le niveau de charges.',
  'Prévoir assurance responsabilité civile professionnelle.',
  'Vérifier bail, local, ERP ou autorisation d’exercice à domicile.',
  'Pour un fonctionnaire : autorisation hiérarchique avant immatriculation.',
];

const List<String> _foodVigilanceDom = [
  'Pour un snack : hygiène alimentaire, déclaration sanitaire et assurance.',
  'Si vente d’alcool : licence et déclaration mairie avant ouverture.',
  'Anticiper stockage froid, eau, électricité, transport et conformité du local.',
  'Pour un fonctionnaire : autorisation hiérarchique avant immatriculation.',
];

final List<JeMeLanceRegionData> jeMeLanceRegionList = [
  JeMeLanceRegionData(
    code: 'GP',
    name: 'Guadeloupe',
    contacts: _domContacts('Guadeloupe'),
    aides: _standardAides,
    vigilance: _foodVigilanceDom,
  ),
  JeMeLanceRegionData(
    code: 'MQ',
    name: 'Martinique',
    contacts: _domContacts('Martinique'),
    aides: _standardAides,
    vigilance: _foodVigilanceDom,
  ),
  JeMeLanceRegionData(
    code: 'GF',
    name: 'Guyane',
    contacts: _domContacts('Guyane'),
    aides: _standardAides,
    vigilance: _foodVigilanceDom,
  ),
  JeMeLanceRegionData(
    code: 'RE',
    name: 'La Réunion',
    contacts: _domContacts('La Réunion'),
    aides: _standardAides,
    vigilance: _foodVigilanceDom,
  ),
  JeMeLanceRegionData(
    code: 'YT',
    name: 'Mayotte',
    contacts: _domContacts('Mayotte'),
    aides: _standardAides,
    vigilance: _foodVigilanceDom,
  ),
  JeMeLanceRegionData(
      code: 'IDF',
      name: 'Île-de-France',
      contacts: _standardContacts('Île-de-France'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'ARA',
      name: 'Auvergne-Rhône-Alpes',
      contacts: _standardContacts('Auvergne-Rhône-Alpes'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'BFC',
      name: 'Bourgogne-Franche-Comté',
      contacts: _standardContacts('Bourgogne-Franche-Comté'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'BRE',
      name: 'Bretagne',
      contacts: _standardContacts('Bretagne'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'CVL',
      name: 'Centre-Val de Loire',
      contacts: _standardContacts('Centre-Val de Loire'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'COR',
      name: 'Corse',
      contacts: _standardContacts('Corse'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'GES',
      name: 'Grand Est',
      contacts: _standardContacts('Grand Est'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'HDF',
      name: 'Hauts-de-France',
      contacts: _standardContacts('Hauts-de-France'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'NOR',
      name: 'Normandie',
      contacts: _standardContacts('Normandie'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'NAQ',
      name: 'Nouvelle-Aquitaine',
      contacts: _standardContacts('Nouvelle-Aquitaine'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'OCC',
      name: 'Occitanie',
      contacts: _standardContacts('Occitanie'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'PDL',
      name: 'Pays de la Loire',
      contacts: _standardContacts('Pays de la Loire'),
      aides: _standardAides,
      vigilance: _standardVigilance),
  JeMeLanceRegionData(
      code: 'PAC',
      name: 'Provence-Alpes-Côte d’Azur',
      contacts: _standardContacts('Provence-Alpes-Côte d’Azur'),
      aides: _standardAides,
      vigilance: _standardVigilance),
];

JeMeLanceRegionData getJeMeLanceRegionByCode(String code) {
  return jeMeLanceRegionList.firstWhere(
    (region) => region.code == code,
    orElse: () => jeMeLanceRegionList.first,
  );
}
