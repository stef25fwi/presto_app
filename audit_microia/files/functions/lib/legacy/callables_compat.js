"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminSetMicroIaConfig = exports.adminGetMicroIaConfig = exports.microIaProcessAudio = exports.getUserPresenceStatus = exports.adminGetUserStats = exports.generateOfferDraft = exports.placesDetails = exports.placesAutocomplete = void 0;
// Compatibility bridge: these callables still live in the legacy root entrypoint.
const legacy = require("../../index.js");
exports.placesAutocomplete = legacy.placesAutocomplete;
exports.placesDetails = legacy.placesDetails;
exports.generateOfferDraft = legacy.generateOfferDraft;
exports.adminGetUserStats = legacy.adminGetUserStats;
exports.getUserPresenceStatus = legacy.getUserPresenceStatus;
exports.microIaProcessAudio = legacy.microIaProcessAudio;
exports.adminGetMicroIaConfig = legacy.adminGetMicroIaConfig;
exports.adminSetMicroIaConfig = legacy.adminSetMicroIaConfig;
//# sourceMappingURL=callables_compat.js.map