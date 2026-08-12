import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import * as https from "https";

import {ENFORCE_APP_CHECK} from "../../config/env";
import {
  assertDeclaredLeaderNames,
  matchDeclaredLeader,
} from "./siretLeaderMatching";

if (!getApps().length) {
  initializeApp();
}

const REGION = "europe-west1";
const API_HOST = "recherche-entreprises.api.gouv.fr";
const VERIFIED_STATUS = "verified_siret_leader_match";
const VERIFIED_SOURCE = "api_recherche_entreprises_siret_leader_match";

type AnyMap = Record<string, any>;

export const verifySiret = onCall(
  {
    region: REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    cors: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Vous devez être connecté pour vérifier un SIRET."
      );
    }

    const uid = request.auth.uid;
    const rawSiret = String(request.data?.siret ?? "");
    const siret = normalizeSiret(rawSiret);

    if (!/^\d{14}$/.test(siret)) {
      await logAttempt(uid, siret, "invalid_format");
      throw new HttpsError(
        "invalid-argument",
        "Le SIRET doit contenir exactement 14 chiffres."
      );
    }

    if (!isValidSiretChecksum(siret)) {
      await logAttempt(uid, siret, "invalid_checksum");
      throw new HttpsError(
        "invalid-argument",
        "Le numéro SIRET est invalide."
      );
    }

    let declaredLeader: {firstName: string; lastName: string};
    try {
      declaredLeader = assertDeclaredLeaderNames(
        request.data?.leaderFirstName,
        request.data?.leaderLastName
      );
    } catch (_) {
      await logAttempt(uid, siret, "invalid_declared_leader_name");
      throw new HttpsError(
        "invalid-argument",
        "Indiquez le nom et le prénom du dirigeant déclaré."
      );
    }

    await rateLimit(uid);

    const apiPath = `/search?q=${encodeURIComponent(siret)}&per_page=5`;
    const json = await getJsonFromOfficialApi(apiPath);

    const results = Array.isArray(json.results) ? json.results : [];
    const match = findMatchingEstablishment(results, siret);

    if (!match.company || !match.establishment) {
      await logAttempt(uid, siret, "not_found");
      throw new HttpsError(
        "not-found",
        "Aucun établissement actif trouvé avec ce SIRET."
      );
    }

    const company = match.company;
    const establishment = match.establishment;

    if (!isActiveEstablishment(company, establishment)) {
      await logAttempt(uid, siret, "inactive_establishment");
      throw new HttpsError(
        "failed-precondition",
        "Cet établissement semble fermé ou inactif."
      );
    }

    const leaderMatch = matchDeclaredLeader(
      company,
      declaredLeader.firstName,
      declaredLeader.lastName
    );

    if (!leaderMatch.matched) {
      await logAttempt(uid, siret, "declared_leader_mismatch");
      throw new HttpsError(
        "failed-precondition",
        "Le nom et le prénom déclarés ne concordent pas avec un dirigeant personne physique associé à cette entreprise dans la source administrative consultée."
      );
    }

    const siren = siret.substring(0, 9);

    const companyName =
      company.nom_complet ||
      company.nom_raison_sociale ||
      company.nom_commercial ||
      company.denomination ||
      "";

    const address =
      establishment.adresse ||
      establishment.libelle_adresse ||
      company.siege?.adresse ||
      "";

    const postalCode =
      establishment.code_postal ||
      company.siege?.code_postal ||
      "";

    const city =
      establishment.libelle_commune ||
      establishment.commune ||
      company.siege?.libelle_commune ||
      "";

    const nafCode =
      establishment.activite_principale ||
      company.activite_principale ||
      "";

    const db = getFirestore();

    // Ne persister dans le profil que les éléments nécessaires à prouver
    // le niveau de contrôle. Le nom/prénom du dirigeant déclaré sert à la
    // comparaison en mémoire et n'est pas conservé dans pro_profiles.
    const proData = {
      uid,
      siret,
      siren,
      companyName,
      address,
      postalCode,
      city,
      nafCode,
      establishmentActive: true,
      siretVerified: true,
      proStatus: VERIFIED_STATUS,
      verifiedSource: VERIFIED_SOURCE,
      verifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    await db.collection("pro_profiles").doc(uid).set(proData, {merge: true});

    // Conserver la compatibilité du document users sans y créer un nouveau
    // signal renforcé : le statut autoritatif de concordance reste celui de
    // pro_profiles, dont proStatus est protégé par les règles Firestore.
    await db.collection("users").doc(uid).set(
      {
        accountType: "pro",
        proStatus: "verified_siret",
        siretVerified: true,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    await logAttempt(uid, siret, "verified_siret_declared_leader_match");

    // Les données déclarées sont renvoyées à la requête courante afin
    // d'expliquer le résultat sans les conserver durablement dans le profil.
    return {
      ok: true,
      siret,
      siren,
      companyName,
      address,
      postalCode,
      city,
      nafCode,
      proStatus: VERIFIED_STATUS,
      leaderDeclaredMatch: true,
      declaredLeaderFirstName: leaderMatch.declaredFirstName,
      declaredLeaderLastName: leaderMatch.declaredLastName,
      declaredLeaderRole: leaderMatch.role,
      verificationLevel: "siret_declared_leader_match",
    };
  }
);

function normalizeSiret(value: string): string {
  return value.replace(/\D/g, "");
}

function isValidSiretChecksum(siret: string): boolean {
  if (!/^\d{14}$/.test(siret)) return false;

  let sum = 0;

  for (let i = 0; i < siret.length; i++) {
    let digit = Number(siret[i]);

    if (i % 2 === 0) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }

    sum += digit;
  }

  if (sum % 10 === 0) return true;

  // Exception historique souvent rencontrée pour certains SIRET La Poste.
  if (siret.startsWith("356000000")) {
    return sum % 5 === 0;
  }

  return false;
}

function findMatchingEstablishment(results: AnyMap[], siret: string): {
  company: AnyMap | null;
  establishment: AnyMap | null;
} {
  for (const company of results) {
    const establishments: AnyMap[] = [];

    if (company.siege) {
      establishments.push(company.siege);
    }

    if (Array.isArray(company.matching_etablissements)) {
      establishments.push(...company.matching_etablissements);
    }

    for (const establishment of establishments) {
      if (String(establishment?.siret ?? "") === siret) {
        return {company, establishment};
      }
    }
  }

  return {company: null, establishment: null};
}

function isActiveEstablishment(company: AnyMap, establishment: AnyMap): boolean {
  const rawStatus =
    establishment.etat_administratif ||
    establishment.etat_administratif_etablissement ||
    company.etat_administratif ||
    "";

  const status = String(rawStatus).trim().toUpperCase();

  if (status === "A" || status === "ACTIF" || status === "ACTIVE") {
    return true;
  }

  if (status === "F" || status === "FERME" || status === "FERMÉ") {
    return false;
  }

  if (establishment.date_fermeture || company.date_fermeture) {
    return false;
  }

  // Si l'API ne renvoie pas le statut mais trouve l'établissement,
  // on ne valide pas aveuglément : on demande une revue manuelle côté app si besoin.
  return false;
}

async function rateLimit(uid: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection("pro_verification_rate_limits").doc(uid);
  const now = Date.now();

  const snap = await ref.get();
  const data = snap.exists ? snap.data() || {} : {};
  const lastAttemptMs = Number(data.lastAttemptMs || 0);

  if (lastAttemptMs && now - lastAttemptMs < 5000) {
    throw new HttpsError(
      "resource-exhausted",
      "Veuillez attendre quelques secondes avant une nouvelle vérification."
    );
  }

  await ref.set(
    {
      uid,
      lastAttemptMs: now,
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true}
  );
}

async function logAttempt(
  uid: string,
  siret: string,
  status: string
): Promise<void> {
  const db = getFirestore();

  await db.collection("pro_verification_logs").add({
    uid,
    siret: siret || null,
    status,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function getJsonFromOfficialApi(path: string): Promise<AnyMap> {
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: API_HOST,
        path,
        method: "GET",
        headers: {
          "Accept": "application/json",
          "User-Agent": "ilipresto-siret-verification/1.0",
        },
      },
      (res) => {
        let body = "";

        res.setEncoding("utf8");

        res.on("data", (chunk) => {
          body += chunk;
        });

        res.on("end", () => {
          const statusCode = res.statusCode || 0;

          if (statusCode < 200 || statusCode >= 300) {
            logger.error("Official SIRET API error", {
              statusCode,
              body: body.slice(0, 500),
            });

            reject(
              new HttpsError(
                "unavailable",
                "La vérification SIRET est temporairement indisponible."
              )
            );
            return;
          }

          try {
            resolve(JSON.parse(body));
          } catch (error) {
            logger.error("Official SIRET API JSON parse error", error);
            reject(
              new HttpsError(
                "internal",
                "Réponse invalide du service officiel SIRET."
              )
            );
          }
        });
      }
    );

    req.on("error", (error) => {
      logger.error("Official SIRET API request error", error);
      reject(
        new HttpsError(
          "unavailable",
          "La vérification SIRET est temporairement indisponible."
        )
      );
    });

    req.setTimeout(10000, () => {
      req.destroy();
      reject(
        new HttpsError(
          "deadline-exceeded",
          "La vérification SIRET a expiré."
        )
      );
    });

    req.end();
  });
}
