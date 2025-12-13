/// Données locales des villes et codes postaux français
/// Peut servir de fallback si l'API Google Places est indisponible

library city_postal_data;

class CityPostalData {
  final String city;
  final String postalCode;
  final String region;

  const CityPostalData({
    required this.city,
    required this.postalCode,
    required this.region,
  });
}

/// Liste des principales villes françaises avec leurs codes postaux
const List<CityPostalData> kFrenchCitiesData = [
  // Guadeloupe
  CityPostalData(city: "Les Abymes", postalCode: "97139", region: "Guadeloupe"),
  CityPostalData(city: "Pointe-à-Pitre", postalCode: "97110", region: "Guadeloupe"),
  CityPostalData(city: "Baie-Mahault", postalCode: "97122", region: "Guadeloupe"),
  CityPostalData(city: "Petit-Bourg", postalCode: "97170", region: "Guadeloupe"),
  CityPostalData(city: "Gosier", postalCode: "97190", region: "Guadeloupe"),
  CityPostalData(city: "Sainte-Anne", postalCode: "97180", region: "Guadeloupe"),
  CityPostalData(city: "Capesterre-Belle-Eau", postalCode: "97130", region: "Guadeloupe"),
  
  // Martinique
  CityPostalData(city: "Fort-de-France", postalCode: "97200", region: "Martinique"),
  CityPostalData(city: "Le Lamentin", postalCode: "97232", region: "Martinique"),
  CityPostalData(city: "Schoelcher", postalCode: "97233", region: "Martinique"),
  CityPostalData(city: "Le Robert", postalCode: "97231", region: "Martinique"),
  CityPostalData(city: "Ducos", postalCode: "97224", region: "Martinique"),
  
  // Guyane
  CityPostalData(city: "Cayenne", postalCode: "97300", region: "Guyane"),
  CityPostalData(city: "Matoury", postalCode: "97351", region: "Guyane"),
  CityPostalData(city: "Kourou", postalCode: "97310", region: "Guyane"),
  CityPostalData(city: "Remire-Montjoly", postalCode: "97354", region: "Guyane"),
  CityPostalData(city: "Saint-Laurent-du-Maroni", postalCode: "97320", region: "Guyane"),
  
  // La Réunion
  CityPostalData(city: "Saint-Denis", postalCode: "97400", region: "La Réunion"),
  CityPostalData(city: "Saint-Paul", postalCode: "97460", region: "La Réunion"),
  CityPostalData(city: "Saint-Pierre", postalCode: "97410", region: "La Réunion"),
  CityPostalData(city: "Le Tampon", postalCode: "97430", region: "La Réunion"),
  CityPostalData(city: "Saint-André", postalCode: "97440", region: "La Réunion"),
  CityPostalData(city: "Saint-Louis", postalCode: "97450", region: "La Réunion"),
  
  // Mayotte
  CityPostalData(city: "Mamoudzou", postalCode: "97600", region: "Mayotte"),
  CityPostalData(city: "Koungou", postalCode: "97690", region: "Mayotte"),
  CityPostalData(city: "Dzaoudzi", postalCode: "97610", region: "Mayotte"),
  
  // Île-de-France
  CityPostalData(city: "Paris", postalCode: "75001", region: "Île-de-France"),
  CityPostalData(city: "Boulogne-Billancourt", postalCode: "92100", region: "Île-de-France"),
  CityPostalData(city: "Argenteuil", postalCode: "95100", region: "Île-de-France"),
  CityPostalData(city: "Montreuil", postalCode: "93100", region: "Île-de-France"),
  CityPostalData(city: "Versailles", postalCode: "78000", region: "Île-de-France"),
  
  // Provence-Alpes-Côte d'Azur
  CityPostalData(city: "Marseille", postalCode: "13001", region: "Provence-Alpes-Côte d'Azur"),
  CityPostalData(city: "Nice", postalCode: "06000", region: "Provence-Alpes-Côte d'Azur"),
  CityPostalData(city: "Toulon", postalCode: "83000", region: "Provence-Alpes-Côte d'Azur"),
  CityPostalData(city: "Aix-en-Provence", postalCode: "13100", region: "Provence-Alpes-Côte d'Azur"),
  CityPostalData(city: "Cannes", postalCode: "06400", region: "Provence-Alpes-Côte d'Azur"),
  
  // Auvergne-Rhône-Alpes
  CityPostalData(city: "Lyon", postalCode: "69001", region: "Auvergne-Rhône-Alpes"),
  CityPostalData(city: "Grenoble", postalCode: "38000", region: "Auvergne-Rhône-Alpes"),
  CityPostalData(city: "Saint-Étienne", postalCode: "42000", region: "Auvergne-Rhône-Alpes"),
  CityPostalData(city: "Villeurbanne", postalCode: "69100", region: "Auvergne-Rhône-Alpes"),
  
  // Occitanie
  CityPostalData(city: "Toulouse", postalCode: "31000", region: "Occitanie"),
  CityPostalData(city: "Montpellier", postalCode: "34000", region: "Occitanie"),
  CityPostalData(city: "Nîmes", postalCode: "30000", region: "Occitanie"),
  CityPostalData(city: "Perpignan", postalCode: "66000", region: "Occitanie"),
  
  // Nouvelle-Aquitaine
  CityPostalData(city: "Bordeaux", postalCode: "33000", region: "Nouvelle-Aquitaine"),
  CityPostalData(city: "Limoges", postalCode: "87000", region: "Nouvelle-Aquitaine"),
  CityPostalData(city: "Poitiers", postalCode: "86000", region: "Nouvelle-Aquitaine"),
  CityPostalData(city: "La Rochelle", postalCode: "17000", region: "Nouvelle-Aquitaine"),
  
  // Bretagne
  CityPostalData(city: "Rennes", postalCode: "35000", region: "Bretagne"),
  CityPostalData(city: "Brest", postalCode: "29200", region: "Bretagne"),
  CityPostalData(city: "Quimper", postalCode: "29000", region: "Bretagne"),
  CityPostalData(city: "Lorient", postalCode: "56100", region: "Bretagne"),
  
  // Pays de la Loire
  CityPostalData(city: "Nantes", postalCode: "44000", region: "Pays de la Loire"),
  CityPostalData(city: "Angers", postalCode: "49000", region: "Pays de la Loire"),
  CityPostalData(city: "Le Mans", postalCode: "72000", region: "Pays de la Loire"),
  CityPostalData(city: "Saint-Nazaire", postalCode: "44600", region: "Pays de la Loire"),
  
  // Grand Est
  CityPostalData(city: "Strasbourg", postalCode: "67000", region: "Grand Est"),
  CityPostalData(city: "Reims", postalCode: "51100", region: "Grand Est"),
  CityPostalData(city: "Metz", postalCode: "57000", region: "Grand Est"),
  CityPostalData(city: "Mulhouse", postalCode: "68100", region: "Grand Est"),
  
  // Hauts-de-France
  CityPostalData(city: "Lille", postalCode: "59000", region: "Hauts-de-France"),
  CityPostalData(city: "Amiens", postalCode: "80000", region: "Hauts-de-France"),
  CityPostalData(city: "Roubaix", postalCode: "59100", region: "Hauts-de-France"),
  CityPostalData(city: "Tourcoing", postalCode: "59200", region: "Hauts-de-France"),
  
  // Normandie
  CityPostalData(city: "Le Havre", postalCode: "76600", region: "Normandie"),
  CityPostalData(city: "Rouen", postalCode: "76000", region: "Normandie"),
  CityPostalData(city: "Caen", postalCode: "14000", region: "Normandie"),
  
  // Bourgogne-Franche-Comté
  CityPostalData(city: "Dijon", postalCode: "21000", region: "Bourgogne-Franche-Comté"),
  CityPostalData(city: "Besançon", postalCode: "25000", region: "Bourgogne-Franche-Comté"),
  
  // Centre-Val de Loire
  CityPostalData(city: "Orléans", postalCode: "45000", region: "Centre-Val de Loire"),
  CityPostalData(city: "Tours", postalCode: "37000", region: "Centre-Val de Loire"),
  
  // Corse
  CityPostalData(city: "Ajaccio", postalCode: "20000", region: "Corse"),
  CityPostalData(city: "Bastia", postalCode: "20200", region: "Corse"),
];

/// Recherche une ville par code postal
CityPostalData? findCityByPostalCode(String postalCode) {
  try {
    return kFrenchCitiesData.firstWhere(
      (data) => data.postalCode == postalCode,
    );
  } catch (_) {
    return null;
  }
}

/// Recherche des villes correspondant à un préfixe
List<CityPostalData> searchCitiesByPrefix(String prefix) {
  final lowerPrefix = prefix.toLowerCase().trim();
  if (lowerPrefix.isEmpty) return [];
  
  return kFrenchCitiesData.where((data) {
    return data.city.toLowerCase().startsWith(lowerPrefix) ||
           data.postalCode.startsWith(lowerPrefix);
  }).toList();
}
