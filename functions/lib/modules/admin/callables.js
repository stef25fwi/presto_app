"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generatePaymentInfoAudio = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const openai_1 = __importDefault(require("openai"));
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const roles_1 = require("../marketplace/services/roles");
const AUDIO_STORAGE_PATH = "audio/payment_info_popup_fr.mp3";
const PUBLIC_CONFIG_COLLECTION = "public_config";
const PAYMENT_INFO_AUDIO_DOC = "payment_info_audio";
const PAYMENT_INFO_NARRATION_FR = `Avant de payer une prestation sur iliprestō.

La législation prévoit des règles différentes selon le statut du prestataire et le type de prestation. Voici l'essentiel à retenir pour payer en toute sécurité.

Première règle : Prestation avec un professionnel. Le paiement doit pouvoir être justifié. Le prestataire peut remettre une facture ou un justificatif de paiement. Le paiement en espèces est limité à 1 000 euros lorsque le payeur a son domicile fiscal en France.

Deuxième règle : Prestation entre particuliers. Le paiement en espèces est possible lorsqu'il ne s'agit pas d'un besoin professionnel. Une preuve écrite est nécessaire au-delà de 1 500 euros.

Troisième règle : Services à la personne à domicile. Pour certaines activités comme le ménage, le jardinage, l'aide à la personne ou le soutien scolaire, le particulier peut utiliser le CESU. Le CESU permet de déclarer et rémunérer l'intervenant.

Quatrième règle : Pour plus de sécurité. Privilégiez toujours un paiement traçable pour protéger le client comme le prestataire en cas de litige. La carte bancaire, le virement, le paiement sécurisé ou un reçu écrit sont recommandés.

Les moyens de paiement acceptés sur iliprestō sont : la carte bancaire, le virement bancaire classique ou instantané, les espèces dans le cadre légal, le portefeuille électronique ou application mobile, le chèque, et le paiement sécurisé intégré iliprestō.

Important : ilipresto.fr est un outil de communication et de petites annonces. La plateforme facilite la visibilité des offres et demandes, mais les relations, accords et prestations restent exclusivement conclus et gérés entre les utilisateurs.`;
exports.generatePaymentInfoAudio = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: [env_1.OPENAI_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
}, async (request) => {
    const token = request.auth?.token;
    if (!token) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const roles = (0, roles_1.extractRolesFromAuthToken)(token);
    (0, roles_1.requireAnyRole)(roles, ["admin", "superadmin"], "Admin access required");
    const apiKey = env_1.OPENAI_API_KEY.value();
    if (!apiKey) {
        throw new https_1.HttpsError("failed-precondition", "OPENAI_API_KEY not configured");
    }
    const openai = new openai_1.default({ apiKey });
    const response = await openai.audio.speech.create({
        model: "tts-1",
        voice: "nova",
        input: PAYMENT_INFO_NARRATION_FR,
        response_format: "mp3",
    });
    const arrayBuffer = await response.arrayBuffer();
    const mp3Buffer = Buffer.from(arrayBuffer);
    const bucket = firebase_admin_1.default.storage().bucket();
    const file = bucket.file(AUDIO_STORAGE_PATH);
    await file.save(mp3Buffer, {
        metadata: { contentType: "audio/mpeg" },
    });
    await file.makePublic();
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${AUDIO_STORAGE_PATH}`;
    await firebase_admin_1.default.firestore()
        .collection(PUBLIC_CONFIG_COLLECTION)
        .doc(PAYMENT_INFO_AUDIO_DOC)
        .set({
        enabled: true,
        audioUrl: publicUrl,
        storagePath: AUDIO_STORAGE_PATH,
        fileName: "payment_info_popup_fr.mp3",
        contentType: "audio/mpeg",
        generatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        generatedBy: request.auth?.uid ?? "unknown",
        source: "tts_openai",
    }, { merge: true });
    return { audioUrl: publicUrl };
});
//# sourceMappingURL=callables.js.map