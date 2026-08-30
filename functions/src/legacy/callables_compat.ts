type LegacyCallableExportMap = {
  placesAutocomplete: unknown;
  placesDetails: unknown;
  generateOfferDraft: unknown;
  openAiExtractListingFields: unknown;
  openAiTranscribeListingAudio: unknown;
  openAiExtractListingFieldsFromAudio: unknown;
  adminGetAccessStatus: unknown;
  getMyAdminAccessStatus: unknown;
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
export const openAiExtractListingFields = legacy.openAiExtractListingFields;
export const openAiTranscribeListingAudio = legacy.openAiTranscribeListingAudio;
export const openAiExtractListingFieldsFromAudio = legacy.openAiExtractListingFieldsFromAudio;
export const adminGetAccessStatus = legacy.adminGetAccessStatus;
export const getMyAdminAccessStatus = legacy.getMyAdminAccessStatus;
export const adminGetUserStats = legacy.adminGetUserStats;
export const getUserPresenceStatus = legacy.getUserPresenceStatus;
export const microIaProcessAudio = legacy.microIaProcessAudio;
export const adminGetMicroIaConfig = legacy.adminGetMicroIaConfig;
export const adminSetMicroIaConfig = legacy.adminSetMicroIaConfig;
