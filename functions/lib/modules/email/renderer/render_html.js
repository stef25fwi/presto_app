"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.renderHtml = renderHtml;
function renderHtml(templateHtml, data) {
    let html = templateHtml;
    for (const [key, value] of Object.entries(data)) {
        const safeValue = String(value ?? "");
        html = html.replaceAll(`{{${key}}}`, safeValue);
    }
    return html;
}
//# sourceMappingURL=render_html.js.map