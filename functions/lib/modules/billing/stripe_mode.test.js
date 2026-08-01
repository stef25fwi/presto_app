"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const stripe_mode_1 = require("./stripe_mode");
(0, node_test_1.default)("le mode se déduit du préfixe de la clé", () => {
    strict_1.default.equal((0, stripe_mode_1.stripeModeFromSecret)("sk_test_abc"), "test");
    strict_1.default.equal((0, stripe_mode_1.stripeModeFromSecret)("sk_live_abc"), "live");
    strict_1.default.equal((0, stripe_mode_1.stripeModeFromSecret)("rk_test_abc"), "test");
    strict_1.default.equal((0, stripe_mode_1.stripeModeFromSecret)("rk_live_abc"), "live");
});
(0, node_test_1.default)("une clé au format inconnu ne donne aucun mode", () => {
    strict_1.default.equal((0, stripe_mode_1.stripeModeFromSecret)(""), null);
    strict_1.default.equal((0, stripe_mode_1.stripeModeFromSecret)("pk_live_abc"), null);
    strict_1.default.equal((0, stripe_mode_1.stripeModeFromSecret)("whsec_abc"), null);
});
(0, node_test_1.default)("les espaces autour de la clé ne changent rien", () => {
    strict_1.default.equal((0, stripe_mode_1.stripeModeFromSecret)("  sk_live_abc  "), "live");
});
(0, node_test_1.default)("une clé réelle n'est acceptée que sur le projet de production", () => {
    strict_1.default.equal((0, stripe_mode_1.isStripeModeAllowedForProject)("live", "presto-app-74abe"), true);
    strict_1.default.equal((0, stripe_mode_1.isStripeModeAllowedForProject)("live", "presto-app-staging"), false);
    strict_1.default.equal((0, stripe_mode_1.isStripeModeAllowedForProject)("live", ""), false);
});
(0, node_test_1.default)("une clé de test est acceptée partout, production comprise", () => {
    strict_1.default.equal((0, stripe_mode_1.isStripeModeAllowedForProject)("test", "presto-app-74abe"), true);
    strict_1.default.equal((0, stripe_mode_1.isStripeModeAllowedForProject)("test", "presto-app-staging"), true);
});
(0, node_test_1.default)("un événement de test reçu avec une clé réelle est un écart", () => {
    strict_1.default.equal((0, stripe_mode_1.livemodeVerdict)(false, "live"), "mismatch");
    strict_1.default.equal((0, stripe_mode_1.livemodeVerdict)(true, "test"), "mismatch");
});
(0, node_test_1.default)("un événement cohérent avec la clé est accepté", () => {
    strict_1.default.equal((0, stripe_mode_1.livemodeVerdict)(true, "live"), "match");
    strict_1.default.equal((0, stripe_mode_1.livemodeVerdict)(false, "test"), "match");
});
(0, node_test_1.default)("un livemode absent ne permet aucune conclusion", () => {
    // Refuser ici casserait les rejeux et les charges utiles tronquées : on
    // laisse passer plutôt que de perdre l'événement.
    strict_1.default.equal((0, stripe_mode_1.livemodeVerdict)(undefined, "live"), "unknown");
    strict_1.default.equal((0, stripe_mode_1.livemodeVerdict)(null, "test"), "unknown");
    strict_1.default.equal((0, stripe_mode_1.livemodeVerdict)("true", "live"), "unknown");
});
(0, node_test_1.default)("le message d'écart nomme les deux côtés", () => {
    strict_1.default.match((0, stripe_mode_1.describeModeMismatch)(false, "live"), /test/);
    strict_1.default.match((0, stripe_mode_1.describeModeMismatch)(false, "live"), /live/);
});
//# sourceMappingURL=stripe_mode.test.js.map