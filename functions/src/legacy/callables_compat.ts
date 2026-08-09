import { IS_EMULATOR } from "../config/env";

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
//
// The legacy root also registers v1 functions during module evaluation. With
// firebase-functions v7, loading that entire root inside every Functions
// Emulator worker can fail before unrelated v2 callables are invoked. Production
// keeps the historical bridge unchanged; emulator-only workers skip the legacy
// root so isolated v2 integration tests can execute without importing unrelated
// v1 registration code.
const legacy = IS_EMULATOR
  ? ({} as LegacyCallableExportMap)
  : require("../../index.js") as LegacyCallableExportMap;

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
