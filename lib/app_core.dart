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
    'Distribution flyers / échantillons',
    'Inventaire magasin',
    'Aide livraison',
    'Aide débarras / encombrants',
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
};

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
    SessionState.userEmail = 'demo@presto.app';
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