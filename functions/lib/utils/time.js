"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nowMs = nowMs;
exports.plusMinutes = plusMinutes;
function nowMs() {
    return Date.now();
}
function plusMinutes(baseMs, minutes) {
    return baseMs + minutes * 60_000;
}
//# sourceMappingURL=time.js.map