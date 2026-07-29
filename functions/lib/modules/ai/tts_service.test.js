"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const tts_service_1 = require("./tts_service");
(0, node_test_1.default)("TTS cache hash includes model voice format and text", () => {
    const first = (0, tts_service_1.buildTtsTextHash)("Bonjour", {
        model: "tts-1",
        voice: "alloy",
        responseFormat: "mp3",
    });
    const same = (0, tts_service_1.buildTtsTextHash)("Bonjour", {
        model: "tts-1",
        voice: "alloy",
        responseFormat: "mp3",
    });
    const differentVoice = (0, tts_service_1.buildTtsTextHash)("Bonjour", {
        model: "tts-1",
        voice: "nova",
        responseFormat: "mp3",
    });
    strict_1.default.equal(first, same);
    strict_1.default.notEqual(first, differentVoice);
});
(0, node_test_1.default)("resolveTtsConfig uses explicit voice and stable defaults", () => {
    const config = (0, tts_service_1.resolveTtsConfig)("nova");
    strict_1.default.equal(config.voice, "nova");
    strict_1.default.equal(config.responseFormat, "mp3");
    strict_1.default.ok(config.model.length > 0);
});
//# sourceMappingURL=tts_service.test.js.map