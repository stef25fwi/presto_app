import 'package:flutter/material.dart';

/// Couleurs globales Prestō
const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

/// Villes + codes postaux (exemples Guadeloupe / Martinique)
const Map<String, String> kCityPostalMap = {
  // Guadeloupe
  'Baie-Mahault': '97122',
  'Les Abymes': '97139',
  'Pointe-à-Pitre': '97110',
  'Le Gosier': '97190',
  'Sainte-Anne': '97180',
  'Saint-François': '97118',
  'Petit-Bourg': '97170',
  'Lamentin': '97129',
  'Capesterre-Belle-Eau': '97130',
  'Basse-Terre': '97100',
  'Goyave': '97128',
  'Morne-à-l\'Eau': '97111',
  'Sainte-Rose': '97115',
  'Le Moule': '97160',
  'Saint-Claude': '97120',
  'Bouillante': '97125',
  'Deshaies': '97126',
  'Trois-Rivières': '97114',
  'Vieux-Habitants': '97119',
  'Vieux-Fort': '97141',
  'Anse-Bertrand': '97121',
  'Port-Louis': '97117',
  'Petit-Canal': '97131',
  'La Désirade': '97127',
  'Terre-de-Bas': '97136',
  'Terre-de-Haut': '97137',
  'Marie-Galante': '97140',
  // Martinique
  'Fort-de-France': '97200',
  'Le Lamentin': '97232',
  'Schoelcher': '97233',
  'Le Robert': '97231',
  'Le François': '97240',
  'Le Marin': '97290',
  'Les Trois-Îlets': '97229',
  'Sainte-Luce': '97228',
  'Sainte-Anne (MQ)': '97227',
  'La Trinité': '97220',
  'Le Lorrain': '97214',
  'Le Carbet': '97221',
  'Le Diamant': '97223',
  'Saint-Esprit': '97270',
};

final List<String> kCityNames = kCityPostalMap.keys.toList();

/// Sous-catégories par catégorie iliprestō
const Map<String, List<String>> kCategorySubcategories = {
  'Restauration / Extra': <String>[
    'Service en salle',
    'Bar / Barman',
    'Plonge / Vaisselle',
    'Aide cuisine / Commis',
    'Chef de partie / Cuisinier',
    'Snack / Fast-food',
    'Food truck / Événementiel',
    'Petit-déjeuner / Brunch',
    'Service banquet / Mariage',
    'Traiteur à domicile',
  ],
  'Bricolage / Travaux': <String>[
    'Montage de meubles',
    'Pose de luminaires',
    'Pose de tringles / étagères',
    'Réparation électroménager',
    'Petits travaux électricité',
    'Petits travaux plomberie',
    'Pose de cloison / placo',
    'Pose de carrelage / faïence',
    'Réparation portail / clôture',
    'Installation TV / support mural',
  ],
  'Aide à domicile': <String>[
    'Ménage régulier',
    'Ménage ponctuel / grand nettoyage',
    'Repassage',
    'Aide aux courses',
    'Préparation des repas',
    'Accompagnement personnes âgées',
    'Aide administrative / papiers',
    'Gardiennage maison (absence)',
    'Nettoyage après déménagement',
    'Organisation / rangement',
  ],
  'Garde d\'enfants': <String>[
    'Baby-sitting soirée',
    'Sortie d\'école / crèche',
    'Garde périscolaire',
    'Garde week-end',
    'Garde vacances scolaires',
    'Garde occasionnelle urgence',
    'Garde à domicile temps plein',
    'Garde partagée',
    'Accompagnement activités',
    'Aide aux devoirs légère',
  ],
  'Événementiel / DJ': <String>[
    'DJ soirée privée',
    'DJ mariage',
    'DJ anniversaire',
    'Location sono / lumières',
    'Animateur micro / MC',
    'Photographe événement',
    'Vidéaste événement',
    'Serveur / barman événementiel',
    'Décoration de salle',
    'Organisation complète événement',
  ],
  'Cours & soutien': <String>[
    'Aide aux devoirs primaire',
    'Soutien collège',
    'Soutien lycée',
    'Maths / Physique',
    'Français / Langues',
    'Anglais',
    'Espagnol',
    'Initiation informatique',
    'Cours de musique',
    'Coaching sport / fitness',
    'Préparation examens / concours',
  ],
  'Jardinage': <String>[
    'Tonte de pelouse',
    'Taille de haies',
    'Débroussaillage',
    'Désherbage / nettoyage massif',
    'Élagage léger',
    'Création de massifs / plantations',
    'Arrosage / entretien régulier',
    'Évacuation des végétaux',
    'Entretien jardin location',
    'Entretien potager',
  ],
  'Peinture': <String>[
    'Peinture chambre / salon',
    'Peinture façade',
    'Peinture grille / portail',
    'Préparation murs (enduit, ponçage)',
    'Rafraîchissement appartement',
    'Peinture boiseries',
    'Peinture plafond',
    'Peinture escalier / cage',
    'Peinture décorative',
    'Rénovation locative express',
  ],
  'Main-d\'oeuvre': <String>[
    'Aide déménagement',
    'Chargement / déchargement',
    'Port de charges lourdes',
    'Manutention chantier',
    'Montage / démontage stands',
    'Manutention événementielle',
    'Vigile / sécurité événementielle',
    'Distribution flyers / échantillons',
    'Inventaire magasin',
    'Aide livraison',
    'Aide débarras / encombrants',
  ],
  'Petits travaux de mécanique': <String>[
    'Auto – entretien courant',
    'Auto – petites réparations',
    'Auto – diagnostic simple',
    'Moto / scooter – entretien courant',
    'Moto / scooter – petites réparations',
    'Montage de pièces & accessoires',
  ],
  'Autre': <String>[
    'Informatique / dépannage',
    'Réseaux sociaux / contenu',
    'Nettoyage véhicule',
    'Aide administrative / comptable',
    'Coaching perso / pro',
    'Traduction',
    'Promenade animaux / pet-sitting',
    'Couture / retouches',
    'Assistance shooting photo',
    'Autre service ponctuel',
  ],
  'Agriculture': <String>[
    'Agriculteur',
  ],
  'Digital / Communication': <String>[
    'Influenceur',
  ],
  'Digital / Création': <String>[
    'Créateur de contenu digital',
  ],
};

class PublishCategoryPairRule {
  final List<String> keywords;
  final String category;
  final String subCategory;
  final String? suggestedTitle;

  const PublishCategoryPairRule({
    required this.keywords,
    required this.category,
    required this.subCategory,
    this.suggestedTitle,
  });
}

class PublishCategoryPairMatch {
  final String category;
  final String subCategory;
  final String? suggestedTitle;
  final String matchedKeyword;

  const PublishCategoryPairMatch({
    required this.category,
    required this.subCategory,
    required this.suggestedTitle,
    required this.matchedKeyword,
  });
}

const List<PublishCategoryPairRule> kPublishCategoryPairRules = [
  PublishCategoryPairRule(
    keywords: [
      'vidange voiture',
      'vidange auto',
      'filtre a huile',
      'filtre a air voiture',
      'bougies voiture',
      'niveau huile voiture',
      'niveaux voiture',
      'entretien voiture',
      'entretien auto',
    ],
    category: 'Petits travaux de mécanique',
    subCategory: 'Auto – entretien courant',
    suggestedTitle: 'Entretien courant automobile',
  ),
  PublishCategoryPairRule(
    keywords: [
      'batterie voiture',
      'batterie auto',
      'ampoule voiture',
      'essuie glace',
      'petite reparation voiture',
      'petites reparations voiture',
      'petite piece voiture',
      'reparation voiture',
    ],
    category: 'Petits travaux de mécanique',
    subCategory: 'Auto – petites réparations',
    suggestedTitle: 'Petite réparation automobile',
  ),
  PublishCategoryPairRule(
    keywords: [
      'voyant moteur',
      'voyant voiture',
      'diagnostic voiture',
      'diagnostic auto',
      'controle visuel voiture',
      'panne legere voiture',
    ],
    category: 'Petits travaux de mécanique',
    subCategory: 'Auto – diagnostic simple',
    suggestedTitle: 'Diagnostic automobile simple',
  ),
  PublishCategoryPairRule(
    keywords: [
      'vidange moto',
      'vidange scooter',
      'bougie moto',
      'bougie scooter',
      'batterie moto',
      'batterie scooter',
      'chaine moto',
      'chaine scooter',
      'entretien moto',
      'entretien scooter',
    ],
    category: 'Petits travaux de mécanique',
    subCategory: 'Moto / scooter – entretien courant',
    suggestedTitle: 'Entretien courant moto / scooter',
  ),
  PublishCategoryPairRule(
    keywords: [
      'petite reparation moto',
      'petites reparations moto',
      'petite reparation scooter',
      'petites reparations scooter',
      'reparation moto',
      'reparation scooter',
      'eclairage moto',
      'eclairage scooter',
      'commande moto',
      'commande scooter',
      'petite piece moto',
      'petite piece scooter',
    ],
    category: 'Petits travaux de mécanique',
    subCategory: 'Moto / scooter – petites réparations',
    suggestedTitle: 'Petite réparation moto / scooter',
  ),
  PublishCategoryPairRule(
    keywords: [
      'autoradio',
      'installer autoradio',
      'montage accessoire voiture',
      'montage accessoires voiture',
      'montage piece auto',
      'montage pieces auto',
      'montage piece moto',
      'montage pieces moto',
    ],
    category: 'Petits travaux de mécanique',
    subCategory: 'Montage de pièces & accessoires',
    suggestedTitle: 'Montage de pièces et accessoires',
  ),
  PublishCategoryPairRule(
    keywords: [
      'mecanicien',
      'mecano',
      'mecanique auto',
      'mecanique voiture',
    ],
    category: 'Petits travaux de mécanique',
    subCategory: 'Auto – petites réparations',
    suggestedTitle: 'Petits travaux de mécanique automobile',
  ),
  PublishCategoryPairRule(
    keywords: [
      'mecanique moto',
      'mecanique scooter',
    ],
    category: 'Petits travaux de mécanique',
    subCategory: 'Moto / scooter – petites réparations',
    suggestedTitle: 'Petits travaux de mécanique moto / scooter',
  ),
  PublishCategoryPairRule(
    keywords: [
      'fuite d eau',
      'fuite eau',
      'plomberie',
      'robinet',
      'canalisation',
      'evier bouche'
    ],
    category: 'Bricolage / Travaux',
    subCategory: 'Petits travaux plomberie',
    suggestedTitle: 'Petits travaux plomberie',
  ),
  PublishCategoryPairRule(
    keywords: [
      'prise electrique',
      'interrupteur',
      'disjoncteur',
      'luminaire',
      'electricite',
      'tableau electrique'
    ],
    category: 'Bricolage / Travaux',
    subCategory: 'Petits travaux électricité',
    suggestedTitle: 'Petits travaux électricité',
  ),
  PublishCategoryPairRule(
    keywords: [
      'monter meuble',
      'montage meuble',
      'ikea',
      'armoire',
      'commode',
      'lit a monter',
      'meuble'
    ],
    category: 'Bricolage / Travaux',
    subCategory: 'Montage de meubles',
    suggestedTitle: 'Montage de meubles',
  ),
  PublishCategoryPairRule(
    keywords: ['support mural', 'tv murale', 'fixation tv', 'tele au mur'],
    category: 'Bricolage / Travaux',
    subCategory: 'Installation TV / support mural',
    suggestedTitle: 'Installation TV / support mural',
  ),
  PublishCategoryPairRule(
    keywords: ['tringle', 'etagere', 'etageres', 'pose etagere'],
    category: 'Bricolage / Travaux',
    subCategory: 'Pose de tringles / étagères',
    suggestedTitle: 'Pose de tringles / étagères',
  ),
  PublishCategoryPairRule(
    keywords: ['tonte', 'pelouse', 'gazon'],
    category: 'Jardinage',
    subCategory: 'Tonte de pelouse',
    suggestedTitle: 'Tonte de pelouse',
  ),
  PublishCategoryPairRule(
    keywords: ['haie', 'taille haie', 'tailler haie'],
    category: 'Jardinage',
    subCategory: 'Taille de haies',
    suggestedTitle: 'Taille de haies',
  ),
  PublishCategoryPairRule(
    keywords: ['debroussaillage', 'broussailles', 'ronces'],
    category: 'Jardinage',
    subCategory: 'Débroussaillage',
    suggestedTitle: 'Débroussaillage',
  ),
  PublishCategoryPairRule(
    keywords: ['menage', 'nettoyage', 'grand nettoyage', 'nettoyer'],
    category: 'Aide à domicile',
    subCategory: 'Ménage ponctuel / grand nettoyage',
    suggestedTitle: 'Ménage ponctuel / grand nettoyage',
  ),
  PublishCategoryPairRule(
    keywords: ['repassage'],
    category: 'Aide à domicile',
    subCategory: 'Repassage',
    suggestedTitle: 'Repassage à domicile',
  ),
  PublishCategoryPairRule(
    keywords: ['courses', 'faire les courses'],
    category: 'Aide à domicile',
    subCategory: 'Aide aux courses',
    suggestedTitle: 'Aide aux courses',
  ),
  PublishCategoryPairRule(
    keywords: [
      'garde enfant',
      'garde bebe',
      'baby sitting',
      'babysitting',
      'nounou'
    ],
    category: 'Garde d\'enfants',
    subCategory: 'Baby-sitting soirée',
    suggestedTitle: 'Garde d\'enfants à domicile',
  ),
  PublishCategoryPairRule(
    keywords: ['sortie ecole', 'sortie d ecole', 'creche'],
    category: 'Garde d\'enfants',
    subCategory: 'Sortie d\'école / crèche',
    suggestedTitle: 'Sortie d\'école / crèche',
  ),
  PublishCategoryPairRule(
    keywords: ['peinture', 'repeindre', 'peindre', 'mur a peindre', 'plafond'],
    category: 'Peinture',
    subCategory: 'Peinture chambre / salon',
    suggestedTitle: 'Travaux de peinture intérieure',
  ),
  PublishCategoryPairRule(
    keywords: [
      'demenagement',
      'demenager',
      'chargement',
      'dechargement',
      'porter des cartons'
    ],
    category: 'Main-d\'oeuvre',
    subCategory: 'Aide déménagement',
    suggestedTitle: 'Aide déménagement',
  ),
  PublishCategoryPairRule(
    keywords: ['debarras', 'encombrants'],
    category: 'Main-d\'oeuvre',
    subCategory: 'Aide débarras / encombrants',
    suggestedTitle: 'Aide débarras / encombrants',
  ),
  PublishCategoryPairRule(
    keywords: [
      'vigile',
      'agent de securite',
      'agent sécurité',
      'agent de sécurité',
      'securite evenement',
      'sécurité événement',
      'securite evenementielle',
      'sécurité événementielle',
      'surveillance',
      'gardiennage',
      'gardiennage evenement',
      'gardiennage événement',
      'controle acces',
      'contrôle accès',
    ],
    category: 'Main-d\'oeuvre',
    subCategory: 'Vigile / sécurité événementielle',
    suggestedTitle: 'Vigile / sécurité événementielle',
  ),
  PublishCategoryPairRule(
    keywords: ['ordinateur', 'imprimante', 'wifi', 'internet', 'informatique'],
    category: 'Autre',
    subCategory: 'Informatique / dépannage',
    suggestedTitle: 'Dépannage informatique',
  ),
];

String _normalizePublishRuleText(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('œ', 'oe')
      .replaceAll(RegExp(r"[/\-'’']"), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

PublishCategoryPairMatch? resolvePublishCategoryPairFromText(String input) {
  final normalizedInput = _normalizePublishRuleText(input);
  if (normalizedInput.isEmpty) return null;

  PublishCategoryPairRule? bestRule;
  String? bestKeyword;
  var bestScore = -1;

  for (final rule in kPublishCategoryPairRules) {
    var score = 0;
    String? matchedKeyword;

    for (final keyword in rule.keywords) {
      final normalizedKeyword = _normalizePublishRuleText(keyword);
      if (normalizedKeyword.isEmpty) continue;
      if (!normalizedInput.contains(normalizedKeyword)) continue;

      final keywordScore = normalizedKeyword.length;
      if (keywordScore > score) {
        score = keywordScore;
        matchedKeyword = keyword;
      }
    }

    if (score > bestScore && matchedKeyword != null) {
      bestScore = score;
      bestRule = rule;
      bestKeyword = matchedKeyword;
    }
  }

  if (bestRule == null || bestKeyword == null) return null;

  return PublishCategoryPairMatch(
    category: bestRule.category,
    subCategory: bestRule.subCategory,
    suggestedTitle: bestRule.suggestedTitle,
    matchedKeyword: bestKeyword,
  );
}

/// État de session global (utilisateur connecté / non connecté)
class SessionState extends ChangeNotifier {
  /// Version "statique" utilisée dans certains fichiers
  static String? userId;
  static String? userEmail;

  /// Version instance pour les écrans qui font sessionState.xxx
  String? displayName;

  bool get isLoggedIn => SessionState.userId != null;
  String? get email => SessionState.userEmail;

  /// Mode démo (utilisé dans login_page.dart)
  void logInDemo() {
    SessionState.userId = 'demo-user';
    SessionState.userEmail = 'demo@ilipresto.app';
    displayName = 'Compte démo';
    notifyListeners();
  }

  /// Mise à jour générale
  void updateUser({String? id, String? email, String? name}) {
    SessionState.userId = id;
    SessionState.userEmail = email;
    displayName = name;
    notifyListeners();
  }

  void logOut() {
    SessionState.userId = null;
    SessionState.userEmail = null;
    displayName = null;
    notifyListeners();
  }
}

/// Instance globale
final sessionState = SessionState();
