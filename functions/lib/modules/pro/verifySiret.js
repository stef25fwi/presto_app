"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifySiret = void 0;
const https_1 = require("firebase-functions/v2/https");
const logger = __importStar(require("firebase-functions/logger"));
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const https = __importStar(require("https"));
const env_1 = require("../../config/env");
if (!(0, app_1.getApps)().length) {
    (0, app_1.initializeApp)();
}
const REGION = "europe-west1";
const API_HOST = "recherche-entreprises.api.gouv.fr";
exports.verifySiret = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    cors: true,
}, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Vous devez être connecté pour vérifier un SIRET.");
    }
    const uid = request.auth.uid;
    const rawSiret = String(request.data?.siret ?? "");
    const siret = normalizeSiret(rawSiret);
    if (!/^\d{14}$/.test(siret)) {
        await logAttempt(uid, siret, "invalid_format");
        throw new https_1.HttpsError("invalid-argument", "Le SIRET doit contenir exactement 14 chiffres.");
    }
    if (!isValidSiretChecksum(siret)) {
        await logAttempt(uid, siret, "invalid_checksum");
        throw new https_1.HttpsError("invalid-argument", "Le numéro SIRET est invalide.");
    }
    await rateLimit(uid);
    const apiPath = `/search?q=${encodeURIComponent(siret)}&per_page=5`;
    const json = await getJsonFromOfficialApi(apiPath);
    const results = Array.isArray(json.results) ? json.results : [];
    const match = findMatchingEstablishment(results, siret);
    if (!match.company || !match.establishment) {
        await logAttempt(uid, siret, "not_found");
        throw new https_1.HttpsError("not-found", "Aucun établissement actif trouvé avec ce SIRET.");
    }
    const company = match.company;
    const establishment = match.establishment;
    if (!isActiveEstablishment(company, establishment)) {
        await logAttempt(uid, siret, "inactive_establishment");
        throw new https_1.HttpsError("failed-precondition", "Cet établissement semble fermé ou inactif.");
    }
    const siren = siret.substring(0, 9);
    const companyName = company.nom_complet ||
        company.nom_raison_sociale ||
        company.nom_commercial ||
        company.denomination ||
        "";
    const address = establishment.adresse ||
        establishment.libelle_adresse ||
        company.siege?.adresse ||
        "";
    const postalCode = establishment.code_postal ||
        company.siege?.code_postal ||
        "";
    const city = establishment.libelle_commune ||
        establishment.commune ||
        company.siege?.libelle_commune ||
        "";
    const nafCode = establishment.activite_principale ||
        company.activite_principale ||
        "";
    const db = (0, firestore_1.getFirestore)();
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
        proStatus: "verified_siret",
        verifiedSource: "api_recherche_entreprises",
        verifiedAt: firestore_1.FieldValue.serverTimestamp(),
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    };
    await db.collection("pro_profiles").doc(uid).set(proData, { merge: true });
    await db.collection("users").doc(uid).set({
        accountType: "pro",
        proStatus: "verified_siret",
        siretVerified: true,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    await logAttempt(uid, siret, "verified");
    return {
        ok: true,
        siret,
        siren,
        companyName,
        address,
        postalCode,
        city,
        nafCode,
        proStatus: "verified_siret",
    };
});
function normalizeSiret(value) {
    return value.replace(/\D/g, "");
}
function isValidSiretChecksum(siret) {
    if (!/^\d{14}$/.test(siret))
        return false;
    let sum = 0;
    for (let i = 0; i < siret.length; i++) {
        let digit = Number(siret[i]);
        if (i % 2 === 0) {
            digit *= 2;
            if (digit > 9)
                digit -= 9;
        }
        sum += digit;
    }
    if (sum % 10 === 0)
        return true;
    // Exception historique souvent rencontrée pour certains SIRET La Poste.
    if (siret.startsWith("356000000")) {
        return sum % 5 === 0;
    }
    return false;
}
function findMatchingEstablishment(results, siret) {
    for (const company of results) {
        const establishments = [];
        if (company.siege) {
            establishments.push(company.siege);
        }
        if (Array.isArray(company.matching_etablissements)) {
            establishments.push(...company.matching_etablissements);
        }
        for (const establishment of establishments) {
            if (String(establishment?.siret ?? "") === siret) {
                return { company, establishment };
            }
        }
    }
    return { company: null, establishment: null };
}
function isActiveEstablishment(company, establishment) {
    const rawStatus = establishment.etat_administratif ||
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
async function rateLimit(uid) {
    const db = (0, firestore_1.getFirestore)();
    const ref = db.collection("pro_verification_rate_limits").doc(uid);
    const now = Date.now();
    const snap = await ref.get();
    const data = snap.exists ? snap.data() || {} : {};
    const lastAttemptMs = Number(data.lastAttemptMs || 0);
    if (lastAttemptMs && now - lastAttemptMs < 5000) {
        throw new https_1.HttpsError("resource-exhausted", "Veuillez attendre quelques secondes avant une nouvelle vérification.");
    }
    await ref.set({
        uid,
        lastAttemptMs: now,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function logAttempt(uid, siret, status) {
    const db = (0, firestore_1.getFirestore)();
    await db.collection("pro_verification_logs").add({
        uid,
        siret: siret || null,
        status,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
}
function getJsonFromOfficialApi(path) {
    return new Promise((resolve, reject) => {
        const req = https.request({
            hostname: API_HOST,
            path,
            method: "GET",
            headers: {
                "Accept": "application/json",
                "User-Agent": "ilipresto-siret-verification/1.0",
            },
        }, (res) => {
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
                    reject(new https_1.HttpsError("unavailable", "La vérification SIRET est temporairement indisponible."));
                    return;
                }
                try {
                    resolve(JSON.parse(body));
                }
                catch (error) {
                    logger.error("Official SIRET API JSON parse error", error);
                    reject(new https_1.HttpsError("internal", "Réponse invalide du service officiel SIRET."));
                }
            });
        });
        req.on("error", (error) => {
            logger.error("Official SIRET API request error", error);
            reject(new https_1.HttpsError("unavailable", "La vérification SIRET est temporairement indisponible."));
        });
        req.setTimeout(10000, () => {
            req.destroy();
            reject(new https_1.HttpsError("deadline-exceeded", "La vérification SIRET a expiré."));
        });
        req.end();
    });
}
//# sourceMappingURL=verifySiret.js.map