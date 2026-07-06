/// Correspondance métier (clé vision) → catégorie/sous-catégorie ilipresto.
///
/// Usage :
///   final match = kTradeLookup[metierId]; // null si inconnu
///   if (match != null && match.confidence >= kTradeConfidenceThreshold) {
///     setState(() {
///       _category      = match.categorie;
///       _selectedSubCategory = match.sousCat;
///     });
///   }
///
/// Le champ [metierId] est retourné par la Cloud Function `classifyServicePhoto`
/// sous la forme { "metier": "<metierId>", "confidence": 0.0-1.0 }.
/// La catégorie et la sous-catégorie sont résolues localement (0 ms) sans
/// aucun appel réseau supplémentaire.

library;

/// Seuil de confiance en dessous duquel on n'applique pas le lookup automatique
/// et on laisse l'utilisateur choisir manuellement.
const double kTradeConfidenceThreshold = 0.60;

/// Résultat d'un lookup métier → catégorie/sous-catégorie.
class TradeCategoryMatch {
  final String categorie;
  final String sousCat;
  final List<String> tags;

  const TradeCategoryMatch({
    required this.categorie,
    required this.sousCat,
    required this.tags,
  });
}

/// Table de correspondance clé-métier → catégorie ilipresto.
///
/// Les clés correspondent à l'enum fermé renvoyé par le modèle vision
/// (voir [kVisionClassificationPrompt]).
/// Les valeurs [categorie] et [sousCat] sont les chaînes exactes de
/// [kCategorySubcategories] dans app_core.dart.
const Map<String, TradeCategoryMatch> kTradeLookup = {
  // ── Restauration / Extra ───────────────────────────────────────────────────
  'serveur': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Service en salle',
    tags: ['service', 'restaurant', 'salle', 'extra'],
  ),
  'barman': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Bar / Barman',
    tags: ['cocktail', 'bar', 'boisson', 'barman'],
  ),
  'plongeur': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Plonge / Vaisselle',
    tags: ['vaisselle', 'plonge', 'cuisine', 'nettoyage'],
  ),
  'commis_cuisine': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Aide cuisine / Commis',
    tags: ['cuisine', 'commis', 'aide', 'préparation'],
  ),
  'cuisinier': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Chef de partie / Cuisinier',
    tags: ['cuisine', 'chef', 'plat', 'restauration'],
  ),
  'snack': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Snack / Fast-food',
    tags: ['snack', 'fast-food', 'sandwich', 'burger'],
  ),
  'food_truck': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Food truck / Événementiel',
    tags: ['food truck', 'événement', 'mobile', 'street food'],
  ),
  'traiteur': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Traiteur à domicile',
    tags: ['traiteur', 'domicile', 'repas', 'buffet'],
  ),
  'banquet': TradeCategoryMatch(
    categorie: 'Restauration / Extra',
    sousCat: 'Service banquet / Mariage',
    tags: ['mariage', 'banquet', 'service', 'cérémonie'],
  ),

  // ── Bricolage / Travaux ────────────────────────────────────────────────────
  'plombier': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Petits travaux plomberie',
    tags: ['plomberie', 'fuite', 'sanitaire', 'robinetterie'],
  ),
  'electricien': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Petits travaux électricité',
    tags: ['électricité', 'prise', 'câblage', 'disjoncteur'],
  ),
  'montage_meubles': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Montage de meubles',
    tags: ['montage', 'meuble', 'assemblage', 'flat-pack'],
  ),
  'luminaire': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Pose de luminaires',
    tags: ['luminaire', 'éclairage', 'lampe', 'plafond'],
  ),
  'etagere': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Pose de tringles / étagères',
    tags: ['étagère', 'tringle', 'rideau', 'fixation murale'],
  ),
  'electromenager': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Réparation électroménager',
    tags: ['électroménager', 'réparation', 'lave-linge', 'frigo'],
  ),
  'carreleur': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Pose de carrelage / faïence',
    tags: ['carrelage', 'faïence', 'sol', 'pose'],
  ),
  'plaquiste': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Pose de cloison / placo',
    tags: ['placo', 'cloison', 'plaquiste', 'isolation'],
  ),
  'portail': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Réparation portail / clôture',
    tags: ['portail', 'clôture', 'serrure', 'réparation'],
  ),
  'installation_tv': TradeCategoryMatch(
    categorie: 'Bricolage / Travaux',
    sousCat: 'Installation TV / support mural',
    tags: ['TV', 'support mural', 'fixation', 'home cinéma'],
  ),

  // ── Aide à domicile ────────────────────────────────────────────────────────
  'menage': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Ménage régulier',
    tags: ['ménage', 'nettoyage', 'aspirateur', 'entretien'],
  ),
  'nettoyage_grand': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Ménage ponctuel / grand nettoyage',
    tags: ['grand ménage', 'nettoyage', 'fond', 'désinfection'],
  ),
  'repassage': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Repassage',
    tags: ['repassage', 'linge', 'fer à repasser', 'chemise'],
  ),
  'courses': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Aide aux courses',
    tags: ['courses', 'supermarché', 'achats', 'livraison'],
  ),
  'cuisine_domicile': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Préparation des repas',
    tags: ['repas', 'cuisine', 'domicile', 'préparation'],
  ),
  'aide_personne_agee': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Accompagnement personnes âgées',
    tags: ['personnes âgées', 'senior', 'accompagnement', 'aide'],
  ),
  'aide_administrative': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Aide administrative / papiers',
    tags: ['administratif', 'papiers', 'dossier', 'formulaire'],
  ),
  'gardiennage': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Gardiennage maison (absence)',
    tags: ['gardiennage', 'maison', 'surveillance', 'absence'],
  ),
  'nettoyage_demenagement': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Nettoyage après déménagement',
    tags: ['déménagement', 'nettoyage', 'remise en état', 'état des lieux'],
  ),
  'rangement': TradeCategoryMatch(
    categorie: 'Aide à domicile',
    sousCat: 'Organisation / rangement',
    tags: ['rangement', 'organisation', 'tri', 'désencombrement'],
  ),

  // ── Garde d'enfants ────────────────────────────────────────────────────────
  'baby_sitter': TradeCategoryMatch(
    categorie: "Garde d'enfants",
    sousCat: 'Baby-sitting soirée',
    tags: ['baby-sitting', 'soirée', 'enfants', 'garde'],
  ),
  'sortie_ecole': TradeCategoryMatch(
    categorie: "Garde d'enfants",
    sousCat: "Sortie d'école / crèche",
    tags: ['école', 'sortie', 'crèche', 'récupérer'],
  ),
  'garde_periscolaire': TradeCategoryMatch(
    categorie: "Garde d'enfants",
    sousCat: 'Garde périscolaire',
    tags: ['périscolaire', 'garderie', 'mercredi', 'cantine'],
  ),
  'garde_weekend': TradeCategoryMatch(
    categorie: "Garde d'enfants",
    sousCat: 'Garde week-end',
    tags: ['week-end', 'garde', 'samedi', 'dimanche'],
  ),
  'garde_vacances': TradeCategoryMatch(
    categorie: "Garde d'enfants",
    sousCat: 'Garde vacances scolaires',
    tags: ['vacances', 'scolaires', 'été', 'juillet'],
  ),
  'garde_domicile': TradeCategoryMatch(
    categorie: "Garde d'enfants",
    sousCat: 'Garde à domicile temps plein',
    tags: [
      'garde domicile',
      'temps plein',
      'nourrice',
      'assistante maternelle'
    ],
  ),

  // ── Événementiel / DJ ──────────────────────────────────────────────────────
  'dj': TradeCategoryMatch(
    categorie: 'Événementiel / DJ',
    sousCat: 'DJ soirée privée',
    tags: ['DJ', 'soirée', 'musique', 'animation'],
  ),
  'dj_mariage': TradeCategoryMatch(
    categorie: 'Événementiel / DJ',
    sousCat: 'DJ mariage',
    tags: ['DJ', 'mariage', 'cérémonie', 'réception'],
  ),
  'sono': TradeCategoryMatch(
    categorie: 'Événementiel / DJ',
    sousCat: 'Location sono / lumières',
    tags: ['sono', 'lumières', 'location matériel', 'enceintes'],
  ),
  'animateur': TradeCategoryMatch(
    categorie: 'Événementiel / DJ',
    sousCat: 'Animateur micro / MC',
    tags: ['animateur', 'MC', 'micro', 'ambiance'],
  ),
  'photographe': TradeCategoryMatch(
    categorie: 'Événementiel / DJ',
    sousCat: 'Photographe événement',
    tags: ['photo', 'photographe', 'reportage', 'shooting'],
  ),
  'videaste': TradeCategoryMatch(
    categorie: 'Événementiel / DJ',
    sousCat: 'Vidéaste événement',
    tags: ['vidéo', 'vidéaste', 'film', 'montage'],
  ),
  'decoration_salle': TradeCategoryMatch(
    categorie: 'Événementiel / DJ',
    sousCat: 'Décoration de salle',
    tags: ['décoration', 'salle', 'ballons', 'fleurs'],
  ),
  'organisation_evenement': TradeCategoryMatch(
    categorie: 'Événementiel / DJ',
    sousCat: 'Organisation complète événement',
    tags: ['événement', 'organisation', 'planification', 'anniversaire'],
  ),

  // ── Cours & soutien ────────────────────────────────────────────────────────
  'soutien_primaire': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Aide aux devoirs primaire',
    tags: ['devoirs', 'primaire', 'CP', 'CE', 'CM'],
  ),
  'soutien_college': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Soutien collège',
    tags: ['collège', 'soutien', '6e', '5e', '4e', '3e'],
  ),
  'soutien_lycee': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Soutien lycée',
    tags: ['lycée', 'bac', 'terminale', 'seconde'],
  ),
  'maths_physique': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Maths / Physique',
    tags: ['maths', 'physique', 'algèbre', 'équations'],
  ),
  'francais_langues': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Français / Langues',
    tags: ['français', 'orthographe', 'grammaire', 'rédaction'],
  ),
  'anglais': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Anglais',
    tags: ['anglais', 'english', 'TOEFL', 'conversation'],
  ),
  'espagnol': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Espagnol',
    tags: ['espagnol', 'español', 'langues'],
  ),
  'informatique_cours': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Initiation informatique',
    tags: ['informatique', 'ordinateur', 'internet', 'débutant'],
  ),
  'musique': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Cours de musique',
    tags: ['musique', 'guitare', 'piano', 'solfège'],
  ),
  'coaching_sport': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Coaching sport / fitness',
    tags: ['sport', 'fitness', 'coach', 'entraînement'],
  ),
  'concours': TradeCategoryMatch(
    categorie: 'Cours & soutien',
    sousCat: 'Préparation examens / concours',
    tags: ['concours', 'examen', 'bac', 'prépa'],
  ),

  // ── Jardinage ──────────────────────────────────────────────────────────────
  'tonte': TradeCategoryMatch(
    categorie: 'Jardinage',
    sousCat: 'Tonte de pelouse',
    tags: ['tonte', 'pelouse', 'herbe', 'gazon'],
  ),
  'taille_haies': TradeCategoryMatch(
    categorie: 'Jardinage',
    sousCat: 'Taille de haies',
    tags: ['haie', 'taille', 'arbuste', 'cisaille'],
  ),
  'debroussaillage': TradeCategoryMatch(
    categorie: 'Jardinage',
    sousCat: 'Débroussaillage',
    tags: ['débroussaillage', 'terrain', 'broussailles', 'friche'],
  ),
  'desherbage': TradeCategoryMatch(
    categorie: 'Jardinage',
    sousCat: 'Désherbage / nettoyage massif',
    tags: ['désherbage', 'mauvaises herbes', 'massif', 'jardin'],
  ),
  'elagage': TradeCategoryMatch(
    categorie: 'Jardinage',
    sousCat: 'Élagage léger',
    tags: ['élagage', 'arbre', 'taille', 'branches'],
  ),
  'plantation': TradeCategoryMatch(
    categorie: 'Jardinage',
    sousCat: 'Création de massifs / plantations',
    tags: ['plantation', 'massif', 'fleurs', 'création jardin'],
  ),
  'potager': TradeCategoryMatch(
    categorie: 'Jardinage',
    sousCat: 'Entretien potager',
    tags: ['potager', 'légumes', 'entretien', 'semis'],
  ),

  // ── Peinture ───────────────────────────────────────────────────────────────
  'peintre': TradeCategoryMatch(
    categorie: 'Peinture',
    sousCat: 'Peinture chambre / salon',
    tags: ['peinture', 'mur', 'salon', 'chambre'],
  ),
  'peinture_facade': TradeCategoryMatch(
    categorie: 'Peinture',
    sousCat: 'Peinture façade',
    tags: ['façade', 'ravalement', 'extérieur', 'peinture'],
  ),
  'peinture_portail': TradeCategoryMatch(
    categorie: 'Peinture',
    sousCat: 'Peinture grille / portail',
    tags: ['portail', 'grille', 'métal', 'anti-rouille'],
  ),
  'enduit': TradeCategoryMatch(
    categorie: 'Peinture',
    sousCat: 'Préparation murs (enduit, ponçage)',
    tags: ['enduit', 'ponçage', 'préparation mur', 'rebouchage'],
  ),
  'renovation_locative': TradeCategoryMatch(
    categorie: 'Peinture',
    sousCat: 'Rénovation locative express',
    tags: ['rénovation', 'locatif', 'remise en état', 'peinture'],
  ),

  // ── Main-d'oeuvre ──────────────────────────────────────────────────────────
  'demenageur': TradeCategoryMatch(
    categorie: "Main-d'oeuvre",
    sousCat: 'Aide déménagement',
    tags: ['déménagement', 'cartons', 'meubles', 'transport'],
  ),
  'manutention': TradeCategoryMatch(
    categorie: "Main-d'oeuvre",
    sousCat: 'Manutention chantier',
    tags: ['manutention', 'chantier', 'charges lourdes', 'livraison'],
  ),
  'vigile': TradeCategoryMatch(
    categorie: "Main-d'oeuvre",
    sousCat: 'Vigile / sécurité événementielle',
    tags: ['sécurité', 'vigile', 'agent', 'événement'],
  ),
  'distribution_flyers': TradeCategoryMatch(
    categorie: "Main-d'oeuvre",
    sousCat: 'Distribution flyers / échantillons',
    tags: ['flyers', 'distribution', 'street marketing', 'échantillons'],
  ),
  'inventaire': TradeCategoryMatch(
    categorie: "Main-d'oeuvre",
    sousCat: 'Inventaire magasin',
    tags: ['inventaire', 'magasin', 'stock', 'comptage'],
  ),
  'debarras': TradeCategoryMatch(
    categorie: "Main-d'oeuvre",
    sousCat: 'Aide débarras / encombrants',
    tags: ['débarras', 'encombrants', 'vide-grenier', 'évacuation'],
  ),
  'stand': TradeCategoryMatch(
    categorie: "Main-d'oeuvre",
    sousCat: 'Montage / démontage stands',
    tags: ['stand', 'montage', 'exposition', 'foire'],
  ),

  // ── Autre ──────────────────────────────────────────────────────────────────
  'informatique_depannage': TradeCategoryMatch(
    categorie: 'Autre',
    sousCat: 'Informatique / dépannage',
    tags: ['informatique', 'dépannage', 'PC', 'virus'],
  ),
  'reseaux_sociaux': TradeCategoryMatch(
    categorie: 'Autre',
    sousCat: 'Réseaux sociaux / contenu',
    tags: ['réseaux sociaux', 'Instagram', 'contenu', 'community manager'],
  ),
  'nettoyage_vehicule': TradeCategoryMatch(
    categorie: 'Autre',
    sousCat: 'Nettoyage véhicule',
    tags: ['voiture', 'lavage', 'nettoyage', 'détailing'],
  ),
  'coaching_perso': TradeCategoryMatch(
    categorie: 'Autre',
    sousCat: 'Coaching perso / pro',
    tags: ['coaching', 'développement personnel', 'bilan', 'conseil'],
  ),
  'traduction': TradeCategoryMatch(
    categorie: 'Autre',
    sousCat: 'Traduction',
    tags: ['traduction', 'interprète', 'langues', 'document'],
  ),
  'pet_sitting': TradeCategoryMatch(
    categorie: 'Autre',
    sousCat: 'Promenade animaux / pet-sitting',
    tags: ['animaux', 'chien', 'chat', 'promenade'],
  ),
  'couture': TradeCategoryMatch(
    categorie: 'Autre',
    sousCat: 'Couture / retouches',
    tags: ['couture', 'retouche', 'vêtement', 'tissu'],
  ),
  'shooting_photo': TradeCategoryMatch(
    categorie: 'Autre',
    sousCat: 'Assistance shooting photo',
    tags: ['shooting', 'studio', 'assistant photo', 'produit'],
  ),
};

/// Prompt système pour la Cloud Function `classifyServicePhoto`.
///
/// Ce prompt est utilisé côté serveur (Firebase Functions) pour classifier
/// l'image en un identifiant de métier parmi l'enum fermé ci-dessus.
/// Le modèle ne génère PAS de catégorie — il classe uniquement.
/// La catégorie/sous-catégorie est ensuite résolue via [kTradeLookup] côté client.
const String kVisionClassificationPrompt = '''
Tu es un classificateur de services à la personne pour la plateforme ilipresto.

Analyse cette image et identifie le service ou métier principal représenté.

Réponds UNIQUEMENT avec un objet JSON valide, sans texte avant ni après :
{"metier": "<clé>", "confidence": <nombre entre 0.0 et 1.0>}

ENUM FERMÉ — utilise exclusivement une de ces clés exactes :

Restauration : serveur, barman, plongeur, commis_cuisine, cuisinier, snack, food_truck, traiteur, banquet
Bricolage : plombier, electricien, montage_meubles, luminaire, etagere, electromenager, carreleur, plaquiste, portail, installation_tv
Aide domicile : menage, nettoyage_grand, repassage, courses, cuisine_domicile, aide_personne_agee, aide_administrative, gardiennage, nettoyage_demenagement, rangement
Garde enfants : baby_sitter, sortie_ecole, garde_periscolaire, garde_weekend, garde_vacances, garde_domicile
Événementiel : dj, dj_mariage, sono, animateur, photographe, videaste, decoration_salle, organisation_evenement
Cours : soutien_primaire, soutien_college, soutien_lycee, maths_physique, francais_langues, anglais, espagnol, informatique_cours, musique, coaching_sport, concours
Jardinage : tonte, taille_haies, debroussaillage, desherbage, elagage, plantation, potager
Peinture : peintre, peinture_facade, peinture_portail, enduit, renovation_locative
Main-d'oeuvre : demenageur, manutention, vigile, distribution_flyers, inventaire, debarras, stand
Autre : informatique_depannage, reseaux_sociaux, nettoyage_vehicule, coaching_perso, traduction, pet_sitting, couture, shooting_photo

Règles :
- Si tu identifies clairement le service → confidence entre 0.7 et 1.0
- Si l'image est ambiguë mais probable → confidence entre 0.4 et 0.69
- Si l'image n'a aucun service reconnaissable → {"metier": null, "confidence": 0.0}
- NE génère PAS de catégorie ou sous-catégorie — uniquement la clé de l'enum
''';
