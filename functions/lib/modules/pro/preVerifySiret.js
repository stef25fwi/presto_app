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
exports.preVerifySiret = void 0;
const admin = __importStar(require("firebase-admin"));
const https = __importStar(require("https"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const REGION = "europe-west1";
function cleanSiret(value) {
    return String(value ?? "").replace(/\D/g, "");
}
function isValidSiretFormat(siret) {
    return /^\d{14}$/.test(siret);
}
function isValidSiretLuhn(siret) {
    let sum = 0;
    let shouldDouble = false;
    for (let i = siret.length - 1; i >= 0; i -= 1) {
        let digit = Number(siret[i]);
        if (Number.isNaN(digit))
            return false;
        if (shouldDouble) {
            digit *= 2;
            if (digit > 9)
                digit -= 9;
        }
        sum += digit;
        shouldDouble = !shouldDouble;
    }
    // Exception historique La Poste.
    if (siret.startsWith("356000000")) {
        return sum % 5 === 0;
    }
    return sum % 10 === 0;
}
function getJson(url) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, {
            headers: {
                accept: "application/json",
                "user-agent": "ilipresto-siret-precheck/1.0",
            },
            timeout: 10000,
        }, (res) => {
            let body = "";
            res.on("data", (chunk) => {
                body += chunk;
            });
            res.on("end", () => {
                if ((res.statusCode ?? 500) >= 400) {
                    reject(new Error(`API entreprises HTTP ${res.statusCode}`));
                    return;
                }
                try {
                    resolve(JSON.parse(body));
                }
                catch (error) {
                    reject(error);
                }
            });
        });
        req.on("timeout", () => {
            req.destroy(new Error("Timeout API entreprises"));
        });
        req.on("error", reject);
    });
}
async function assertPrecheckRateLimit(siret) {
    const hourKey = new Date().toISOString().slice(0, 13).replace(/[-T:]/g, "");
    const ref = db.collection("siret_preverification_rate_limits").doc(`${siret}_${hourKey}`);
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const current = Number(snap.data()?.count ?? 0);
        const next = current + 1;
        if (next > 20) {
            throw new https_1.HttpsError("resource-exhausted", "Trop de vérifications pour ce SIRET. Réessayez plus tard.");
        }
        tx.set(ref, {
            siret,
            count: next,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
}
function firstNonEmpty(...values) {
    for (const value of values) {
        const text = String(value ?? "").trim();
        if (text.length > 0) {
            return text;
        }
    }
    return "";
}
function findMatchingEstablishment(company, siret) {
    const candidates = [];
    if (company?.siege)
        candidates.push(company.siege);
    if (company?.etablissement)
        candidates.push(company.etablissement);
    if (Array.isArray(company?.matching_etablissements)) {
        candidates.push(...company.matching_etablissements);
    }
    candidates.push(company);
    for (const candidate of candidates) {
        if (cleanSiret(candidate?.siret) === siret) {
            return candidate;
        }
    }
    return null;
}
function resolveAddress(establishment) {
    const rawAddress = establishment?.adresse;
    if (typeof rawAddress === "string") {
        return rawAddress.trim();
    }
    if (rawAddress && typeof rawAddress === "object") {
        return [
            rawAddress.numero_voie,
            rawAddress.type_voie,
            rawAddress.libelle_voie,
            rawAddress.complement_adresse,
        ]
            .map((value) => String(value ?? "").trim())
            .filter(Boolean)
            .join(" ");
    }
    return firstNonEmpty(establishment?.adresse_ligne_1, establishment?.adresse_ligne_2, establishment?.adresse_complete);
}
function assertEstablishmentActive(company, establishment) {
    const rawState = firstNonEmpty(establishment?.etat_administratif, establishment?.etat_administratif_etablissement, company?.etat_administratif).toUpperCase();
    const closedAt = firstNonEmpty(establishment?.date_fermeture, establishment?.date_fin, establishment?.date_cessation);
    const inactive = rawState === "F" ||
        rawState === "FERME" ||
        rawState === "FERMÉ" ||
        rawState === "INACTIF" ||
        rawState === "C";
    if (inactive || closedAt.length > 0) {
        throw new https_1.HttpsError("failed-precondition", "Ce SIRET correspond à un établissement fermé ou inactif.");
    }
}
exports.preVerifySiret = (0, https_1.onCall)({
    region: REGION,
    cors: true,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
}, async (request) => {
    const siret = cleanSiret(request.data?.siret);
    if (!isValidSiretFormat(siret)) {
        throw new https_1.HttpsError("invalid-argument", "Le SIRET doit contenir exactement 14 chiffres.");
    }
    if (!isValidSiretLuhn(siret)) {
        throw new https_1.HttpsError("invalid-argument", "Le numéro SIRET n'est pas valide.");
    }
    await assertPrecheckRateLimit(siret);
    const url = "https://recherche-entreprises.api.gouv.fr/search?q=" +
        encodeURIComponent(siret) +
        "&per_page=5";
    let payload;
    try {
        payload = await getJson(url);
    }
    catch (error) {
        throw new https_1.HttpsError("unavailable", "Vérification SIRET temporairement indisponible. Réessayez.");
    }
    const results = Array.isArray(payload?.results) ? payload.results : [];
    let selectedCompany = null;
    let selectedEstablishment = null;
    for (const company of results) {
        const establishment = findMatchingEstablishment(company, siret);
        if (establishment) {
            selectedCompany = company;
            selectedEstablishment = establishment;
            break;
        }
    }
    if (!selectedCompany || !selectedEstablishment) {
        throw new https_1.HttpsError("not-found", "Aucune entreprise active trouvée pour ce SIRET.");
    }
    assertEstablishmentActive(selectedCompany, selectedEstablishment);
    const siren = siret.substring(0, 9);
    const companyName = firstNonEmpty(selectedCompany?.nom_complet, selectedCompany?.nom_raison_sociale, selectedCompany?.raison_sociale, selectedCompany?.unite_legale?.denomination, selectedCompany?.unite_legale?.nom, selectedEstablishment?.enseigne);
    const city = firstNonEmpty(selectedEstablishment?.libelle_commune, selectedEstablishment?.commune, selectedEstablishment?.adresse?.libelle_commune);
    const postalCode = firstNonEmpty(selectedEstablishment?.code_postal, selectedEstablishment?.adresse?.code_postal);
    const nafCode = firstNonEmpty(selectedCompany?.activite_principale, selectedCompany?.code_naf, selectedEstablishment?.activite_principale, selectedEstablishment?.code_naf);
    return {
        ok: true,
        siret,
        siren,
        companyName,
        address: resolveAddress(selectedEstablishment),
        postalCode,
        city,
        nafCode,
        establishmentActive: true,
        siretVerified: true,
        verifiedSource: "api_recherche_entreprises_precheck",
    };
});
//# sourceMappingURL=preVerifySiret.js.map