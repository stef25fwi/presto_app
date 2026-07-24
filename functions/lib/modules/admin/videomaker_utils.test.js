"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const videomaker_utils_1 = require("./videomaker_utils");
(0, node_test_1.default)("normalizeVideoPrompt trims a valid prompt", () => {
    strict_1.default.equal((0, videomaker_utils_1.normalizeVideoPrompt)("  scène tropicale  "), "scène tropicale");
});
(0, node_test_1.default)("normalizeVideoPrompt rejects an empty prompt", () => {
    strict_1.default.throws(() => (0, videomaker_utils_1.normalizeVideoPrompt)("  "), videomaker_utils_1.VideoMakerValidationError);
});
(0, node_test_1.default)("normalizeAspectRatio defaults to portrait and accepts landscape", () => {
    strict_1.default.equal((0, videomaker_utils_1.normalizeAspectRatio)(undefined), "9:16");
    strict_1.default.equal((0, videomaker_utils_1.normalizeAspectRatio)("16:9"), "16:9");
});
(0, node_test_1.default)("normalizeReferenceImage validates size and mime type", () => {
    const image = (0, videomaker_utils_1.normalizeReferenceImage)(Buffer.from("image").toString("base64"), "image/png");
    strict_1.default.equal(image?.mimeType, "image/png");
    strict_1.default.equal(image?.byteLength, 5);
    const tooLarge = Buffer.alloc(videomaker_utils_1.MAX_REFERENCE_IMAGE_BYTES + 1).toString("base64");
    strict_1.default.throws(() => (0, videomaker_utils_1.normalizeReferenceImage)(tooLarge, "image/jpeg"), videomaker_utils_1.VideoMakerValidationError);
});
(0, node_test_1.default)("normalizeApiKey uses the server secret when the field is empty", () => {
    strict_1.default.equal((0, videomaker_utils_1.normalizeApiKey)("", "server-key"), "server-key");
});
//# sourceMappingURL=videomaker_utils.test.js.map