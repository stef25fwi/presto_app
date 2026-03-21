"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadActiveTemplateVersion = loadActiveTemplateVersion;
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
async function loadActiveTemplateVersion(templateCode, locale) {
    const q = await firestore_1.db
        .collection(constants_1.COLLECTIONS.emailTemplateVersions)
        .where("template_code", "==", templateCode)
        .where("locale", "==", locale)
        .where("status", "==", "active")
        .orderBy("version", "desc")
        .limit(1)
        .get();
    if (q.empty)
        return null;
    const doc = q.docs[0];
    const data = doc.data();
    return {
        template_code: templateCode,
        version: Number(data.version || 1),
        locale,
        subject: String(data.subject || ""),
        preheader: String(data.preheader || ""),
        html: String(data.html || ""),
        text: String(data.text || ""),
    };
}
//# sourceMappingURL=loader.js.map