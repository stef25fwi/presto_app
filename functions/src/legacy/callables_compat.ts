type LegacyCallableExportMap = {
  placesAutocomplete: unknown;
  placesDetails: unknown;
  generateOfferDraft: unknown;
  adminGetUserStats: unknown;
  getUserPresenceStatus: unknown;
  microIaProcessAudio: unknown;
  adminGetMicroIaConfig: unknown;
  adminSetMicroIaConfig: unknown;
};

// Compatibility bridge: these callables still live in the legacy root entrypoint.
const legacy = require("../../index.js") as LegacyCallableExportMap;

export const placesAutocomplete = legacy.placesAutocomplete;
export const placesDetails = legacy.placesDetails;
export const generateOfferDraft = legacy.generateOfferDraft;
export const adminGetUserStats = legacy.adminGetUserStats;
export const getUserPresenceStatus = legacy.getUserPresenceStatus;
export const microIaProcessAudio = legacy.microIaProcessAudio;
export const adminGetMicroIaConfig = legacy.adminGetMicroIaConfig;
export const adminSetMicroIaConfig = legacy.adminSetMicroIaConfig;