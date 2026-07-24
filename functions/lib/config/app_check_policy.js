"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveAppCheckEnforcement = resolveAppCheckEnforcement;
function normalizeBoolean(value) {
    return String(value ?? "").trim().toLowerCase() === "true";
}
function resolveAppCheckEnforcement({ isEmulator, isProduction, enforceValue, safeModeValue, }) {
    if (isEmulator)
        return false;
    if (normalizeBoolean(safeModeValue))
        return false;
    const normalizedEnforce = String(enforceValue ?? "")
        .trim()
        .toLowerCase();
    if (isProduction) {
        return normalizedEnforce !== "false";
    }
    return normalizedEnforce === "true";
}
//# sourceMappingURL=app_check_policy.js.map