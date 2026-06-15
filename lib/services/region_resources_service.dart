class RegionResource {
  final String name;
  final String url;
  final String description;

  const RegionResource({
    required this.name,
    required this.url,
    required this.description,
  });
}

const _kUniversal = <RegionResource>[
  RegionResource(
    name: 'Guichet unique (INPI)',
    url: 'https://procedures.inpi.fr',
    description: 'Immatriculation et formalités entreprise en ligne',
  ),
  RegionResource(
    name: 'URSSAF – Créer son entreprise',
    url: 'https://www.urssaf.fr/portail/home/independant/je-cree-mon-entreprise.html',
    description: 'Cotisations sociales, ACRE et démarches sociales',
  ),
  RegionResource(
    name: 'BPI France',
    url: 'https://www.bpifrance.fr',
    description: 'Financement, garanties et accompagnement entrepreneurs',
  ),
  RegionResource(
    name: 'France Travail (ex Pôle emploi)',
    url: 'https://www.francetravail.fr',
    description: 'ARCE, ARE et aides à la création d\'emploi',
  ),
  RegionResource(
    name: 'CCI France – Trouver ma CCI',
    url: 'https://www.cci.fr',
    description: 'Chambre de Commerce et d\'Industrie de votre territoire',
  ),
  RegionResource(
    name: 'CMA France – Artisanat',
    url: 'https://www.artisanat.fr',
    description: 'Chambre de Métiers et de l\'Artisanat',
  ),
  RegionResource(
    name: 'BGE – Accompagnement',
    url: 'https://www.bge.asso.fr',
    description: 'Accompagnement et formation des créateurs d\'entreprise',
  ),
  RegionResource(
    name: 'Initiative France',
    url: 'https://www.initiative-france.fr',
    description: 'Prêts d\'honneur et réseau d\'accompagnement',
  ),
  RegionResource(
    name: 'Réseau Entreprendre',
    url: 'https://www.reseau-entreprendre.org',
    description: 'Prêts d\'honneur et mentorat par des chefs d\'entreprise',
  ),
  RegionResource(
    name: 'Aides-territoires',
    url: 'https://aides-territoires.beta.gouv.fr',
    description: 'Moteur de recherche d\'aides locales et régionales',
  ),
];

const _kDromExtra = <RegionResource>[
  RegionResource(
    name: 'LADOM',
    url: 'https://www.ladom.fr',
    description: 'Aide à la mobilité et à la formation en Outre-mer',
  ),
  RegionResource(
    name: 'France Active Outre-mer',
    url: 'https://www.franceactive.org',
    description: 'Financement solidaire pour les entrepreneurs des DROM',
  ),
];

const _kRegionalSpecific = <String, List<RegionResource>>{
  'île-de-france': [
    RegionResource(
      name: 'Région Île-de-France',
      url: 'https://www.iledefrance.fr',
      description: 'Aides régionales, appels à projets et financement IDF',
    ),
    RegionResource(
      name: 'Paris&Co',
      url: 'https://www.parisandco.com',
      description: 'Accompagnement startups et innovation en Île-de-France',
    ),
  ],
  'auvergne-rhône-alpes': [
    RegionResource(
      name: 'Région Auvergne-Rhône-Alpes',
      url: 'https://www.auvergnerhonealpes.fr',
      description: 'Aides, appels à projets et financement AuRA',
    ),
  ],
  'occitanie': [
    RegionResource(
      name: 'Région Occitanie',
      url: 'https://www.laregion.fr',
      description: 'Aides régionales et appels à projets Occitanie',
    ),
  ],
  'nouvelle-aquitaine': [
    RegionResource(
      name: 'Région Nouvelle-Aquitaine',
      url: 'https://www.nouvelle-aquitaine.fr',
      description: 'Aides et accompagnement entrepreneurial Nouvelle-Aquitaine',
    ),
  ],
  "provence-alpes-côte d'azur": [
    RegionResource(
      name: 'Région Sud PACA',
      url: 'https://www.maregionsud.fr',
      description: 'Aides régionales Provence-Alpes-Côte d\'Azur',
    ),
  ],
  'bretagne': [
    RegionResource(
      name: 'Région Bretagne',
      url: 'https://www.bretagne.bzh',
      description: 'Aides régionales et appels à projets Bretagne',
    ),
  ],
  'grand est': [
    RegionResource(
      name: 'Région Grand Est',
      url: 'https://www.grandest.fr',
      description: 'Aides et accompagnement entrepreneurial Grand Est',
    ),
  ],
  'hauts-de-france': [
    RegionResource(
      name: 'Région Hauts-de-France',
      url: 'https://www.hautsdefrance.fr',
      description: 'Aides régionales Hauts-de-France',
    ),
  ],
  'normandie': [
    RegionResource(
      name: 'Région Normandie',
      url: 'https://www.normandie.fr',
      description: 'Aides et appels à projets Normandie',
    ),
  ],
  'pays de la loire': [
    RegionResource(
      name: 'Région Pays de la Loire',
      url: 'https://www.paysdelaloire.fr',
      description: 'Aides régionales Pays de la Loire',
    ),
  ],
  'bourgogne-franche-comté': [
    RegionResource(
      name: 'Région Bourgogne-Franche-Comté',
      url: 'https://www.bourgognefranchecomte.fr',
      description: 'Aides régionales et appels à projets BFC',
    ),
  ],
  'centre-val de loire': [
    RegionResource(
      name: 'Région Centre-Val de Loire',
      url: 'https://www.centre-valdeloire.fr',
      description: 'Aides et accompagnement entrepreneurial CVL',
    ),
  ],
  'corse': [
    RegionResource(
      name: 'Collectivité de Corse',
      url: 'https://www.isula.corsica',
      description: 'Aides et appels à projets de la Collectivité de Corse',
    ),
  ],
  'guadeloupe': [
    RegionResource(
      name: 'Région Guadeloupe',
      url: 'https://www.regionguadeloupe.fr',
      description: 'Aides régionales, FEDER et accompagnement Guadeloupe',
    ),
  ],
  'martinique': [
    RegionResource(
      name: 'CTM Martinique',
      url: 'https://www.collectivitedemartinique.mq',
      description: 'Aides de la Collectivité Territoriale de Martinique',
    ),
  ],
  'guyane': [
    RegionResource(
      name: 'CTG Guyane',
      url: 'https://www.ctguyane.fr',
      description: 'Aides de la Collectivité Territoriale de Guyane',
    ),
  ],
  'la réunion': [
    RegionResource(
      name: 'Région La Réunion',
      url: 'https://www.regionreunion.com',
      description: 'Aides régionales et accompagnement La Réunion',
    ),
  ],
  'mayotte': [
    RegionResource(
      name: 'Conseil Départemental de Mayotte',
      url: 'https://www.cg976.fr',
      description: 'Aides départementales et accompagnement Mayotte',
    ),
  ],
};

const _kDromSet = {
  'guadeloupe',
  'martinique',
  'guyane',
  'la réunion',
  'mayotte',
};

bool isDROM(String region) => _kDromSet.contains(region.toLowerCase().trim());

List<RegionResource> getRegionResources(String region) {
  if (region.isEmpty) return [];
  final r = region.toLowerCase().trim();
  final resources = <RegionResource>[..._kUniversal];
  if (_kDromSet.contains(r)) {
    resources.addAll(_kDromExtra);
  }
  final specific = _kRegionalSpecific[r];
  if (specific != null) {
    resources.addAll(specific);
  }
  return resources;
}
