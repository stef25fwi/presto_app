import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";

export interface LoadedTemplateVersion {
  template_code: string;
  version: number;
  locale: "fr" | "en";
  subject: string;
  preheader: string;
  html: string;
  text: string;
}

export async function loadActiveTemplateVersion(
  templateCode: string,
  locale: "fr" | "en",
): Promise<LoadedTemplateVersion | null> {
  const q = await db
    .collection(COLLECTIONS.emailTemplateVersions)
    .where("template_code", "==", templateCode)
    .where("locale", "==", locale)
    .where("status", "==", "active")
    .orderBy("version", "desc")
    .limit(1)
    .get();

  if (q.empty) return null;
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
