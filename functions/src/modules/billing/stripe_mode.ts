/**
 * Cloisonnement entre le Stripe de test et le Stripe réel.
 *
 * Deux confusions coûtent cher et ne se voient pas au déploiement :
 *
 * 1. une clé `sk_live_` configurée sur un projet Firebase qui n'est pas la
 *    production — les paiements réels atterrissent alors dans une base d'essai ;
 * 2. un webhook de test reçu par l'endpoint de production (ou l'inverse) :
 *    Stripe signe les deux avec des secrets distincts, mais un secret recopié
 *    d'un environnement à l'autre rend la signature valide et injecte des
 *    abonnements fantômes.
 *
 * Ce module ne contient que des fonctions pures, testables sans Stripe ni
 * Firestore.
 */

export type StripeMode = "test" | "live";

/** Projets Firebase autorisés à porter une clé Stripe réelle. */
export const LIVE_STRIPE_PROJECT_IDS = new Set<string>(["presto-app-74abe"]);

export function stripeModeFromSecret(secret: string): StripeMode | null {
  const value = String(secret ?? "").trim();
  if (value.startsWith("sk_live_") || value.startsWith("rk_live_")) return "live";
  if (value.startsWith("sk_test_") || value.startsWith("rk_test_")) return "test";
  return null;
}

/**
 * Une clé réelle n'est acceptée que sur un projet de production. L'inverse
 * reste permis : une clé de test sur la production sert aux répétitions avant
 * bascule commerciale.
 */
export function isStripeModeAllowedForProject(
  mode: StripeMode,
  projectId: string,
): boolean {
  if (mode === "test") return true;
  return LIVE_STRIPE_PROJECT_IDS.has(String(projectId ?? "").trim());
}

export type LivemodeVerdict = "match" | "mismatch" | "unknown";

/**
 * Compare le drapeau `livemode` de l'événement au mode de la clé configurée.
 *
 * `unknown` couvre les charges utiles sans `livemode` explicite : on ne peut
 * rien conclure, et refuser serait pire que traiter.
 */
export function livemodeVerdict(
  eventLivemode: unknown,
  keyMode: StripeMode,
): LivemodeVerdict {
  if (typeof eventLivemode !== "boolean") return "unknown";
  const eventMode: StripeMode = eventLivemode ? "live" : "test";
  return eventMode === keyMode ? "match" : "mismatch";
}

export function describeModeMismatch(
  eventLivemode: unknown,
  keyMode: StripeMode,
): string {
  const eventMode = eventLivemode === true ? "live" : "test";
  return `Événement Stripe en mode ${eventMode} reçu avec une clé ${keyMode}`;
}
