import assert from "node:assert/strict";
import test from "node:test";

import {
  describeModeMismatch,
  isStripeModeAllowedForProject,
  livemodeVerdict,
  stripeModeFromSecret,
} from "./stripe_mode";

test("le mode se déduit du préfixe de la clé", () => {
  assert.equal(stripeModeFromSecret("sk_test_abc"), "test");
  assert.equal(stripeModeFromSecret("sk_live_abc"), "live");
  assert.equal(stripeModeFromSecret("rk_test_abc"), "test");
  assert.equal(stripeModeFromSecret("rk_live_abc"), "live");
});

test("une clé au format inconnu ne donne aucun mode", () => {
  assert.equal(stripeModeFromSecret(""), null);
  assert.equal(stripeModeFromSecret("pk_live_abc"), null);
  assert.equal(stripeModeFromSecret("whsec_abc"), null);
});

test("les espaces autour de la clé ne changent rien", () => {
  assert.equal(stripeModeFromSecret("  sk_live_abc  "), "live");
});

test("une clé réelle n'est acceptée que sur le projet de production", () => {
  assert.equal(isStripeModeAllowedForProject("live", "presto-app-74abe"), true);
  assert.equal(isStripeModeAllowedForProject("live", "presto-app-staging"), false);
  assert.equal(isStripeModeAllowedForProject("live", ""), false);
});

test("une clé de test est acceptée partout, production comprise", () => {
  assert.equal(isStripeModeAllowedForProject("test", "presto-app-74abe"), true);
  assert.equal(isStripeModeAllowedForProject("test", "presto-app-staging"), true);
});

test("un événement de test reçu avec une clé réelle est un écart", () => {
  assert.equal(livemodeVerdict(false, "live"), "mismatch");
  assert.equal(livemodeVerdict(true, "test"), "mismatch");
});

test("un événement cohérent avec la clé est accepté", () => {
  assert.equal(livemodeVerdict(true, "live"), "match");
  assert.equal(livemodeVerdict(false, "test"), "match");
});

test("un livemode absent ne permet aucune conclusion", () => {
  // Refuser ici casserait les rejeux et les charges utiles tronquées : on
  // laisse passer plutôt que de perdre l'événement.
  assert.equal(livemodeVerdict(undefined, "live"), "unknown");
  assert.equal(livemodeVerdict(null, "test"), "unknown");
  assert.equal(livemodeVerdict("true", "live"), "unknown");
});

test("le message d'écart nomme les deux côtés", () => {
  assert.match(describeModeMismatch(false, "live"), /test/);
  assert.match(describeModeMismatch(false, "live"), /live/);
});
