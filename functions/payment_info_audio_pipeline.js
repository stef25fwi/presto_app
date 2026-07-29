"use strict";

// Compatibility bridge for the legacy functions/index.js entrypoint.
// The only implementation now lives in src/modules/admin/payment_info_audio.ts
// and is compiled to lib/modules/admin/payment_info_audio.js before deployment.
const unified = require("./lib/modules/admin/payment_info_audio");

module.exports = {
  generatePaymentInfoAudio: unified.generatePaymentInfoAudio,
  generatePaymentInfoAudioDraft: unified.generatePaymentInfoAudioDraft,
  publishPaymentInfoAudioDraft: unified.publishPaymentInfoAudioDraft,
};
