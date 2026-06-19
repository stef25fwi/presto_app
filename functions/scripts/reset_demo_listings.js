const admin = require("firebase-admin");
const fs = require("fs");
const https = require("https");

if (process.env.RESET_DEMO_LISTINGS !== "YES") {
  console.error("❌ Sécurité active : aucune suppression effectuée.");
  console.error("Relance avec : RESET_DEMO_LISTINGS=YES node functions/scripts/reset_demo_listings.js");
  process.exit(1);
}

function projectId() {
  try {
    const f = JSON.parse(fs.readFileSync(".firebaserc", "utf8"));
    return f.projects.default;
  } catch (_) {
    return process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT;
  }
}

admin.initializeApp({ projectId: projectId() });

const db = admin.firestore();
const FV = admin.firestore.FieldValue;
const TEAM_ID = "team_ilipresto_demo";
const TEAM_NAME = "Team iliprestō";

const categories = [
  ["Jardinage", "Entretien extérieur", "Entretien jardin", "Entretien jardin et petits travaux extérieurs.", 80],
  ["Ménage", "Nettoyage logement", "Nettoyage logement", "Nettoyage soigné logement, bureau ou local.", 60],
  ["Bricolage", "Petites réparations", "Petites réparations", "Montage meubles, fixation, petites réparations.", 75],
  ["Transport", "Aide déménagement", "Aide transport", "Aide transport cartons, meubles légers ou électroménager.", 95],
  ["Informatique", "Assistance numérique", "Assistance informatique", "Aide ordinateur, téléphone, imprimante ou Wi-Fi.", 45],
  ["Événementiel", "Aide événement", "Aide événement privé", "Installation tables, chaises et rangement événement.", 110],
];

const collections = [
  "listings",
  "offers",
  "listingPrivateContacts",
  "favorites",
  "listingModeration",
  "listingPhotoReviews",
];

function getJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let body = "";
      res.on("data", (c) => body += c);
      res.on("end", () => resolve(JSON.parse(body)));
    }).on("error", reject);
  });
}

function slug(v) {
  return String(v).toLowerCase().normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

async function deleteCollection(name) {
  let total = 0;
  while (true) {
    const snap = await db.collection(name).limit(450).get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => {
      batch.delete(doc.ref);
      total++;
    });

    await batch.commit();
    console.log(`🗑️ ${name}: ${total} supprimés`);
  }
  console.log(`✅ ${name}: ${total} supprimés`);
}

async function loadDepartments() {
  const url = "https://geo.api.gouv.fr/departements?fields=code,nom,codeRegion,region";
  const rows = await getJson(url);

  return rows
    .filter((d) => d.code && d.nom)
    .sort((a, b) => String(a.code).localeCompare(String(b.code), "fr"))
    .map((d) => {
      const code = String(d.code);
      return {
        code,
        name: String(d.nom),
        regionName: String(d.region?.nom || d.codeRegion || "France"),
        city: cityFor(code, String(d.nom)),
        postalCode: postalFor(code),
      };
    });
}

function cityFor(code, name) {
  const o = {
    "971": "Les Abymes",
    "972": "Fort-de-France",
    "973": "Cayenne",
    "974": "Saint-Denis",
    "976": "Mamoudzou",
    "2A": "Ajaccio",
    "2B": "Bastia",
    "75": "Paris",
  };
  return o[code] || name;
}

function postalFor(code) {
  const o = {
    "971": "97139",
    "972": "97200",
    "973": "97300",
    "974": "97400",
    "976": "97600",
    "2A": "20000",
    "2B": "20200",
    "75": "75001",
  };
  return o[code] || `${String(code).padStart(2, "0")}000`;
}

async function seedTeamProfile(count) {
  const now = FV.serverTimestamp();

  await db.collection("users").doc(TEAM_ID).set({
    uid: TEAM_ID,
    displayName: TEAM_NAME,
    name: TEAM_NAME,
    pseudo: TEAM_NAME,
    role: "Compte démonstration officiel",
    bio: "Profil annonceur officiel utilisé pour les annonces exemple iliprestō.",
    verified: true,
    isVerified: true,
    pro: true,
    accountType: "pro",
    avatarUrl: "",
    photoURL: "",
    createdAt: now,
    updatedAt: now,
    stats: {
      listingsCount: count,
      reviewsCount: 0,
      averageRating: 4.9,
    },
  }, { merge: true });

  console.log(`✅ Profil annonceur créé : ${TEAM_NAME}`);
}

function makeListing(i, dep, count) {
  const c = categories[i % categories.length];
  const id = `demo-${dep.code.toLowerCase().replace(/[^a-z0-9]/g, "")}-team-ilipresto`;
  const now = FV.serverTimestamp();

  return {
    id,
    offerId: id,
    listingId: id,

    ownerId: TEAM_ID,
    userId: TEAM_ID,
    advertiserId: TEAM_ID,
    authorId: TEAM_ID,
    publisherId: TEAM_ID,

    advertiserName: TEAM_NAME,
    advertiserRole: "Annonceur officiel",
    advertiserAvatarUrl: "",
    advertiserRating: 4.9,
    advertiserReviewCount: 0,
    verified: true,

    advertiser: {
      id: TEAM_ID,
      name: TEAM_NAME,
      displayName: TEAM_NAME,
      role: "Annonceur officiel",
      avatarUrl: "",
      verified: true,
      rating: 4.9,
      reviewsCount: 0,
      offersCount: count,
      seniorityLabel: "Profil officiel",
      city: dep.city,
      bio: "Annonce exemple publiée par Team iliprestō.",
      isOnline: true,
      lastSeenLabel: "En ligne",
    },

    title: `${c[2]} — ${dep.name}`,
    description: `${c[3]}\n\nDépartement : ${dep.name} (${dep.code}). Ville exemple : ${dep.city}.`,
    detail: `${c[3]}\n\nAnnonce exemple pour tester l’affichage, les filtres, la recherche et la page détail.`,
    category: c[0],
    subcategory: c[1],
    categoryLabel: c[0],
    subcategoryLabel: c[1],

    city: dep.city,
    postalCode: dep.postalCode,
    location: dep.city,
    address: dep.city,
    departmentCode: dep.code,
    departmentName: dep.name,
    regionCode: slug(dep.regionName),
    regionName: dep.regionName,

    price: c[4],
    budget: c[4],
    budgetMin: c[4],
    budgetMax: c[4],
    hideBudget: false,
    isNegotiable: false,
    paymentMethod: "Paiement à convenir",

    phone: "+590000000000",
    hidePhone: true,
    serviceArea: dep.name,
    canTravel: true,
    schedule: "Flexible",
    availability: "Disponible sur rendez-vous",
    missionDelay: "Sous 48 h",
    averageDelay: "Sous 48 h",
    serviceType: "Prestation ponctuelle",

    status: "active",
    listingStatus: "active",
    moderationStatus: "approved",
    mediaProcessingStatus: "ready",
    visibility: "public",
    source: "demo_seed_team_ilipresto",

    isUrgent: i % 7 === 0,
    urgent: i % 7 === 0,
    statusBadges: i % 7 === 0 ? ["Urgent"] : ["Nouveau"],

    imageUrls: [],
    media: [],
    mediaCount: 0,
    thumbnailUrl: "",
    imageUrl: "",

    viewCount: 0,
    phoneViewCount: 0,
    phoneViews: 0,
    contactViews: 0,
    favoriteCount: 0,
    reportCount: 0,
    contactCount: 0,

    createdAt: now,
    updatedAt: now,
    publishedAt: now,
    expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 7776000000),
  };
}

async function seedListings(deps) {
  let batch = db.batch();

  deps.forEach((dep, i) => {
    const item = makeListing(i, dep, deps.length);
    batch.set(db.collection("listings").doc(item.id), item, { merge: false });
  });

  await batch.commit();
  console.log(`✅ ${deps.length} annonces exemple créées dans listings`);
}

async function main() {
  console.log(`Projet Firebase : ${projectId()}`);

  const deps = await loadDepartments();
  console.log(`Départements détectés : ${deps.length}`);

  if (deps.length < 100) {
    throw new Error(`Nombre de départements insuffisant : ${deps.length}`);
  }

  console.log("⚠️ Suppression des anciennes annonces...");
  for (const name of collections) {
    await deleteCollection(name);
  }

  await seedTeamProfile(deps.length);
  await seedListings(deps);

  const check = await db.collection("listings")
    .where("ownerId", "==", TEAM_ID)
    .get();

  console.log("");
  console.log("==================================================");
  console.log(" TERMINÉ");
  console.log("==================================================");
  console.log(`✅ Annonces Team iliprestō créées : ${check.size}`);
  console.log(`✅ Profil annonceur : ${TEAM_NAME}`);
}

main().catch((e) => {
  console.error("❌ Erreur :", e);
  process.exit(1);
});
