import 'package:flutter/material.dart';

/// Constantes de l'application Presto

/// Infos région (code officiel + nom)
class RegionItem {
  final String code; // ex: '11'
  final String name; // ex: 'Île-de-France'
  final bool isDrom;

  const RegionItem({
    required this.code,
    required this.name,
    required this.isDrom,
  });

  String get label => '$code — $name';
}

/// Liste des régions ordonnées :
/// - d'abord les régions de métropole (codes 11,24,27,...,94)
/// - ensuite les DROM (01,02,03,04,06)
const List<RegionItem> kRegionsOrdered = [
  // Métropole (d'abord)
  RegionItem(code: '11', name: 'Île-de-France', isDrom: false),
  RegionItem(code: '24', name: 'Centre-Val de Loire', isDrom: false),
  RegionItem(code: '27', name: 'Bourgogne-Franche-Comté', isDrom: false),
  RegionItem(code: '28', name: 'Normandie', isDrom: false),
  RegionItem(code: '32', name: 'Hauts-de-France', isDrom: false),
  RegionItem(code: '44', name: 'Grand Est', isDrom: false),
  RegionItem(code: '52', name: 'Pays de la Loire', isDrom: false),
  RegionItem(code: '53', name: 'Bretagne', isDrom: false),
  RegionItem(code: '75', name: 'Nouvelle-Aquitaine', isDrom: false),
  RegionItem(code: '76', name: 'Occitanie', isDrom: false),
  RegionItem(code: '84', name: 'Auvergne-Rhône-Alpes', isDrom: false),
  RegionItem(code: '93', name: "Provence-Alpes-Côte d'Azur", isDrom: false),
  RegionItem(code: '94', name: 'Corse', isDrom: false),

  // DROM (tout en bas)
  RegionItem(code: '01', name: 'Guadeloupe', isDrom: true),
  RegionItem(code: '02', name: 'Martinique', isDrom: true),
  RegionItem(code: '03', name: 'Guyane', isDrom: true),
  RegionItem(code: '04', name: 'La Réunion', isDrom: true),
  RegionItem(code: '06', name: 'Mayotte', isDrom: true),
];

/// Tri les régions par numéro avec les DROM en fin de liste
List<RegionItem> getRegionsSorted() {
  final list = [...kRegionsOrdered];

  int toInt(String s) => int.tryParse(s) ?? 999;

  list.sort((a, b) {
    // 1) Métropole d'abord, DROM à la fin
    if (a.isDrom != b.isDrom) return a.isDrom ? 1 : -1;

    // 2) Tri par code numérique
    return toInt(a.code).compareTo(toInt(b.code));
  });

  return list;
}

/// Dropdown avec séparateur + "fond DROM" en bas
DropdownButtonFormField<RegionItem> buildRegionDropdown({
  required RegionItem? value,
  required void Function(RegionItem?) onChanged,
}) {
  final regions = getRegionsSorted();

  // On construit la liste avec:
  // - une section "Métropole"
  // - une section "DROM" tout en bas, avec fond léger
  final metro = regions.where((r) => !r.isDrom).toList();
  final drom  = regions.where((r) => r.isDrom).toList();

  List<DropdownMenuItem<RegionItem>> header(String text) => [
    DropdownMenuItem<RegionItem>(
      enabled: false,
      value: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  ];

  List<DropdownMenuItem<RegionItem>> itemsFor(List<RegionItem> list, {bool tinted = false}) {
    return list.map((r) {
      return DropdownMenuItem<RegionItem>(
        value: r,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: tinted
              ? BoxDecoration(
                  color: const Color(0xFFF4F4F4), // fond léger DROM
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Text(r.label),
        ),
      );
    }).toList();
  }

  return DropdownButtonFormField<RegionItem>(
    value: value,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: "Région",
      border: OutlineInputBorder(),
    ),
    items: [
      ...header("France métropolitaine"),
      ...itemsFor(metro),
      ...header("DROM"),
      ...itemsFor(drom, tinted: true), // ✅ DROM "en fond de liste" + fond
    ],
    onChanged: onChanged,
  );
}

/// Si tu utilises un mapping région → départements pour le filtre :
const Map<String, List<String>> kRegionDepartments = {
  // Métropole
  '11': ['75', '77', '78', '91', '92', '93', '94', '95'], // Île-de-France
  '24': ['18', '28', '36', '37', '41', '45'],             // Centre-Val de Loire
  '27': ['21', '25', '39', '58', '70', '71', '89', '90'], // Bourgogne-Franche-Comté
  '28': ['14', '27', '50', '61', '76'],                   // Normandie
  '32': ['02', '59', '60', '62', '80'],                   // Hauts-de-France
  '44': ['08', '10', '51', '52', '54', '55', '57', '67', '68', '88'], // Grand Est
  '52': ['44', '49', '53', '72', '85'],                   // Pays de la Loire
  '53': ['22', '29', '35', '56'],                         // Bretagne
  '75': ['16', '17', '19', '23', '24', '33', '40', '47', '64', '79', '86', '87'], // N-A
  '76': ['09', '11', '12', '30', '31', '32', '34', '46', '48', '65', '66', '81', '82'], // Occitanie
  '84': ['01', '03', '07', '15', '26', '38', '42', '43', '63', '69', '73', '74'],      // ARA
  '93': ['04', '05', '06', '13', '83', '84'],             // PACA
  '94': ['2A', '2B'],                                     // Corse

  // DROM
  '01': ['971'], // Guadeloupe
  '02': ['972'], // Martinique
  '03': ['973'], // Guyane
  '04': ['974'], // La Réunion
  '06': ['976'], // Mayotte
};

/// Liste des catégories d'offres
const List<String> kCategories = [
  'Restauration / Extra',
  'Bricolage / Travaux',
  'Aide à domicile',
  'Garde d\'enfants',
  'Événementiel / DJ',
  'Cours & soutien',
  'Jardinage',
  'Peinture',
  'Main-d\'œuvre',
  'Autre',
];

/// Code département → Nom du département
const Map<String, String> kDepartments = {
  // Île-de-France
  '75': 'Paris',
  '77': 'Seine-et-Marne',
  '78': 'Yvelines',
  '91': 'Essonne',
  '92': 'Hauts-de-Seine',
  '93': 'Seine-Saint-Denis',
  '94': 'Val-de-Marne',
  '95': 'Val-d\'Oise',
  // Centre-Val de Loire
  '18': 'Cher',
  '28': 'Eure-et-Loir',
  '36': 'Indre',
  '37': 'Indre-et-Loire',
  '41': 'Loir-et-Cher',
  '45': 'Loiret',
  // Bourgogne-Franche-Comté
  '21': 'Côte-d\'Or',
  '25': 'Doubs',
  '39': 'Jura',
  '58': 'Nièvre',
  '70': 'Haute-Saône',
  '71': 'Saône-et-Loire',
  '89': 'Yonne',
  '90': 'Territoire de Belfort',
  // Normandie
  '14': 'Calvados',
  '27': 'Eure',
  '50': 'Manche',
  '61': 'Orne',
  '76': 'Seine-Maritime',
  // Hauts-de-France
  '02': 'Aisne',
  '59': 'Nord',
  '60': 'Oise',
  '62': 'Pas-de-Calais',
  '80': 'Somme',
  // Grand Est
  '08': 'Ardennes',
  '10': 'Aube',
  '51': 'Marne',
  '52': 'Haute-Marne',
  '54': 'Meurthe-et-Moselle',
  '55': 'Meuse',
  '57': 'Moselle',
  '67': 'Bas-Rhin',
  '68': 'Haut-Rhin',
  '88': 'Vosges',
  // Pays de la Loire
  '44': 'Loire-Atlantique',
  '49': 'Maine-et-Loire',
  '53': 'Mayenne',
  '72': 'Sarthe',
  '85': 'Vendée',
  // Bretagne
  '22': 'Côtes-d\'Armor',
  '29': 'Finistère',
  '35': 'Ille-et-Vilaine',
  '56': 'Morbihan',
  // Nouvelle-Aquitaine
  '16': 'Charente',
  '17': 'Charente-Maritime',
  '19': 'Corrèze',
  '23': 'Creuse',
  '24': 'Dordogne',
  '33': 'Gironde',
  '40': 'Landes',
  '47': 'Lot-et-Garonne',
  '64': 'Pyrénées-Atlantiques',
  '79': 'Deux-Sèvres',
  '86': 'Vienne',
  '87': 'Haute-Vienne',
  // Occitanie
  '09': 'Ariège',
  '11': 'Aude',
  '12': 'Aveyron',
  '30': 'Gard',
  '31': 'Haute-Garonne',
  '32': 'Gers',
  '34': 'Hérault',
  '46': 'Lot',
  '48': 'Lozère',
  '65': 'Hautes-Pyrénées',
  '66': 'Pyrénées-Orientales',
  '81': 'Tarn',
  '82': 'Tarn-et-Garonne',
  // Auvergne-Rhône-Alpes
  '01': 'Ain',
  '03': 'Allier',
  '07': 'Ardèche',
  '15': 'Cantal',
  '26': 'Drôme',
  '38': 'Isère',
  '42': 'Loire',
  '43': 'Haute-Loire',
  '63': 'Puy-de-Dôme',
  '69': 'Rhône',
  '73': 'Savoie',
  '74': 'Haute-Savoie',
  // Provence-Alpes-Côte d'Azur
  '04': 'Alpes-de-Haute-Provence',
  '05': 'Hautes-Alpes',
  '06': 'Alpes-Maritimes',
  '13': 'Bouches-du-Rhône',
  '83': 'Var',
  '84': 'Vaucluse',
  // Corse
  '2A': 'Corse-du-Sud',
  '2B': 'Haute-Corse',
  // DROM
  '971': 'Guadeloupe',
  '972': 'Martinique',
  '973': 'Guyane',
  '974': 'La Réunion',
  '976': 'Mayotte',
};

/// Code région → Libellé affiché
const Map<String, String> kRegions = {
  '01': 'Guadeloupe',
  '02': 'Martinique',
  '03': 'Guyane',
  '04': 'La Réunion',
  '11': 'Île-de-France',
  '24': 'Centre-Val de Loire',
  '27': 'Bourgogne-Franche-Comté',
  '28': 'Normandie',
  '32': 'Hauts-de-France',
  '44': 'Grand Est',
  '52': 'Pays de la Loire',
  '53': 'Bretagne',
  '75': 'Nouvelle-Aquitaine',
  '76': 'Occitanie',
  '84': 'Auvergne-Rhône-Alpes',
  '93': 'Provence-Alpes-Côte d\'Azur',
  '94': 'Corse',
};
