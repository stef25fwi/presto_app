import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ Nom de ta collection Firestore
const String kOffersCollection = 'offers';

/// Normalisation stable (même règle en création + filtre)
String normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[’']"), "'")
    .replaceAll(RegExp(r"[^\p{Letter}\p{Number}]+", unicode: true), '')
    .trim();

/// Déduit dept depuis CP (DOM/TOM: 971/..., Corse 20xxx -> 2A/2B (heuristique))
String deptFromCp(String cp) {
  if (cp.startsWith('97') || cp.startsWith('98')) return cp.substring(0, 3);
  if (cp.startsWith('20'))
    return '2A'; // fallback (si besoin tu gères 2A/2B au choix)
  return cp.substring(0, 2);
}

/// Supprime toute la collection par lots (évite les timeouts)
Future<void> deleteCollectionInBatches(CollectionReference col,
    {int batchSize = 400}) async {
  while (true) {
    final snap = await col.limit(batchSize).get();
    if (snap.docs.isEmpty) break;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}

/// Génère un document offer cohérent (champs filtres + dates)
Map<String, dynamic> _offer({
  required String title,
  required String category,
  required String description,
  required String city,
  required String cp,
  required int budget,
  required DateTime createdAt,
  String status = 'active',
  String type = 'mission',
  bool proOnly = false,
  String? userId,
}) {
  final dept = deptFromCp(cp);
  final cityNorm = normalize(city);
  final keywordsNorm =
      normalize("$title $description $city $cp $dept $category");

  return {
    "title": title,
    "category": category,
    "description": description,

    // 🔥 Compatibilité : écriture des 2 variantes
    "city": city,
    "location": city,
    "cp": cp,
    "postalCode": cp,

    "dept": dept,

    // champs utiles filtres/UX
    "cityNorm": cityNorm,
    "keywordsNorm": keywordsNorm,
    "budget": budget,
    "status": status, // active / closed / draft...
    "type": type, // mission / job / event...
    "proOnly": proOnly, // plus tard pour abonnement pro
    "createdAt": Timestamp.fromDate(createdAt),

    // optionnels (à garder si tu veux)
    "updatedAt": Timestamp.fromDate(createdAt),
    if (userId != null && userId.isNotEmpty) "userId": userId,
  };
}

/// Ajoute rapidement 4 offres complètes pour tester la messagerie.
Future<void> seedMessagingOffers({required String userId}) async {
  final author = userId.trim();
  if (author.isEmpty) {
    throw ArgumentError('userId ne doit pas être vide');
  }

  final fs = FirebaseFirestore.instance;
  final col = fs.collection(kOffersCollection);
  final now = DateTime.now();

  final seed = <Map<String, dynamic>>[
    _offer(
      title: "Extra serveur cocktail (ce soir)",
      category: "Restauration / Extra",
      description: "Service plateau + rangement, tenue noire souhaitée.",
      city: "Paris",
      cp: "75011",
      budget: 90,
      createdAt: now.subtract(const Duration(hours: 2)),
      userId: author,
    ),
    _offer(
      title: "Ménage 3h appartement T2",
      category: "Ménage",
      description: "Aspiration, sols, salle de bain, produits fournis.",
      city: "Lyon",
      cp: "69002",
      budget: 60,
      createdAt: now.subtract(const Duration(hours: 5)),
      userId: author,
    ),
    _offer(
      title: "Bricolage : poser deux étagères",
      category: "Bricolage",
      description: "Perçage placo + chevilles, niveau et vis fournis.",
      city: "Marseille",
      cp: "13006",
      budget: 70,
      createdAt: now.subtract(const Duration(hours: 8)),
      userId: author,
    ),
    _offer(
      title: "Baby-sitting mercredi 18h–21h",
      category: "Baby-sitting",
      description: "Deux enfants (4 et 7 ans), repas réchauffé, coucher.",
      city: "Nantes",
      cp: "44000",
      budget: 45,
      createdAt: now.subtract(const Duration(hours: 12)),
      userId: author,
    ),
  ];

  WriteBatch batch = fs.batch();
  int ops = 0;

  Future<void> commitIfNeeded() async {
    if (ops == 0) return;
    await batch.commit();
    batch = fs.batch();
    ops = 0;
  }

  for (final o in seed) {
    batch.set(col.doc(), o);
    ops++;
    if (ops >= 450) {
      await commitIfNeeded();
    }
  }
  await commitIfNeeded();
}

/// 🔥 Reset total + réinjection d'offres de test
Future<void> resetAndSeedOffers() async {
  final fs = FirebaseFirestore.instance;
  final col = fs.collection(kOffersCollection);

  // 1) DELETE ALL
  await deleteCollectionInBatches(col);

  // 2) SEED
  final now = DateTime.now();

  final seed = <Map<String, dynamic>>[
    // ===== GUADELOUPE (971) =====
    _offer(
      title: "Jardinier cet après-midi à Goyave",
      category: "Jardinage",
      description: "Petit jardin : désherbage / tailles légères. Budget 60€.",
      city: "Goyave",
      cp: "97128",
      budget: 60,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    _offer(
      title: "Ménage 2h – Baie-Mahault",
      category: "Ménage",
      description: "Appartement T2, 2h de ménage. Produits sur place.",
      city: "Baie-Mahault",
      cp: "97122",
      budget: 40,
      createdAt: now.subtract(const Duration(hours: 8)),
    ),
    _offer(
      title: "Bricolage : montage meuble + étagère",
      category: "Bricolage",
      description: "Montage meuble + fixation étagère. Matériel dispo.",
      city: "Les Abymes",
      cp: "97139",
      budget: 50,
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),

    // ===== MARTINIQUE (972) =====
    _offer(
      title: "Extra serveur – soirée privée",
      category: "Restauration / Extra",
      description: "Service boissons + dressage. 19h–23h.",
      city: "Fort-de-France",
      cp: "97200",
      budget: 80,
      createdAt: now.subtract(const Duration(hours: 18)),
    ),

    // ===== GUYANE (973) =====
    _offer(
      title: "Aide déménagement (2h)",
      category: "Transport / Livraison",
      description: "Aide pour porter cartons, 2h, paiement immédiat.",
      city: "Cayenne",
      cp: "97300",
      budget: 70,
      createdAt: now.subtract(const Duration(days: 2)),
    ),

    // ===== RÉUNION (974) =====
    _offer(
      title: "Livraison petit colis – centre ville",
      category: "Transport / Livraison",
      description: "Petit colis à livrer. Départ immédiat.",
      city: "Saint-Denis",
      cp: "97400",
      budget: 25,
      createdAt: now.subtract(const Duration(hours: 10)),
    ),

    // ===== MAYOTTE (976) =====
    _offer(
      title: "Baby-sitting 2 enfants (18h–21h)",
      category: "Baby-sitting",
      description: "2 enfants (4 et 7 ans). Expérience souhaitée.",
      city: "Mamoudzou",
      cp: "97600",
      budget: 45,
      createdAt: now.subtract(const Duration(days: 3)),
    ),

    // ===== POLYNÉSIE FRANÇAISE (987) =====
    _offer(
      title: "Aide jardin – 1h",
      category: "Jardinage",
      description: "Désherbage léger, 1h.",
      city: "Papeete",
      cp: "98714",
      budget: 35,
      createdAt: now.subtract(const Duration(days: 4)),
    ),

    // ===== SAINT-PIERRE-ET-MIQUELON (975) =====
    _offer(
      title: "Aide courses – centre",
      category: "Aide à domicile",
      description: "Besoin d’aide pour faire des courses.",
      city: "Saint-Pierre",
      cp: "97500",
      budget: 30,
      createdAt: now.subtract(const Duration(days: 5)),
    ),

    // ===== MONACO (980) =====
    _offer(
      title: "Nettoyage vitrine (30 min)",
      category: "Ménage",
      description: "Nettoyage vitrine boutique.",
      city: "Monaco",
      cp: "98000",
      budget: 25,
      createdAt: now.subtract(const Duration(hours: 20)),
    ),

    // ===== MÉTROPOLE =====
    _offer(
      title: "Aide déménagement (2h) – Paris",
      category: "Transport / Livraison",
      description: "2h pour porter cartons, ascenseur.",
      city: "Paris",
      cp: "75015",
      budget: 60,
      createdAt: now.subtract(const Duration(hours: 4)),
    ),
    _offer(
      title: "Ménage appartement – Melun",
      category: "Ménage",
      description: "Ménage 3h, produits fournis.",
      city: "Melun",
      cp: "77000",
      budget: 55,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    _offer(
      title: "Jardinage : tonte + bordures",
      category: "Jardinage",
      description: "Tonte + bordures + évacuation déchets verts.",
      city: "Lyon",
      cp: "69008",
      budget: 90,
      createdAt: now.subtract(const Duration(days: 6)),
    ),
    _offer(
      title: "Bricolage : poser tringle + étagère",
      category: "Bricolage",
      description: "Perçage + niveau, matériel disponible.",
      city: "Marseille",
      cp: "13008",
      budget: 50,
      createdAt: now.subtract(const Duration(hours: 22)),
    ),
  ];

  // Batch Firestore (max 500 ops)
  WriteBatch batch = fs.batch();
  int ops = 0;

  Future<void> commitIfNeeded() async {
    if (ops == 0) return;
    await batch.commit();
    batch = fs.batch();
    ops = 0;
  }

  for (final o in seed) {
    batch.set(col.doc(), o);
    ops++;
    if (ops >= 450) {
      await commitIfNeeded();
    }
  }
  await commitIfNeeded();
}

Future<void> patchLegacyOfferCompatFields() async {
  final fs = FirebaseFirestore.instance;
  final col = fs.collection(kOffersCollection);
  final snap = await col.get();

  WriteBatch batch = fs.batch();
  int ops = 0;

  Future<void> commitIfNeeded() async {
    if (ops == 0) return;
    await batch.commit();
    batch = fs.batch();
    ops = 0;
  }

  for (final doc in snap.docs) {
    final data = doc.data();
    final city = (data['city'] ?? '').toString();
    final cp = (data['cp'] ?? '').toString();

    final needsLocation =
        !(data.containsKey('location')) || (data['location'] == null);
    final needsPostalCode =
        !(data.containsKey('postalCode')) || (data['postalCode'] == null);

    if (!needsLocation && !needsPostalCode) continue;
    if (city.isEmpty && cp.isEmpty) continue;

    final patch = <String, dynamic>{};
    if (needsLocation && city.isNotEmpty) patch['location'] = city;
    if (needsPostalCode && cp.isNotEmpty) patch['postalCode'] = cp;

    if (patch.isEmpty) continue;

    batch.set(doc.reference, patch, SetOptions(merge: true));
    ops++;
    if (ops >= 450) {
      await commitIfNeeded();
    }
  }

  await commitIfNeeded();
}
