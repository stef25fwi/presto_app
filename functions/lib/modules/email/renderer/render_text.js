"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.renderText = renderText;
function renderText(templateText, data) {
    let text = templateText;
    for (const [key, value] of Object.entries(data)) {
        const safeValue = String(value ?? "");
        text = text.replaceAll(`{{${key}}}`, safeValue);
    }
    return text;
}
//# sourceMappingURL=render_text.js.map