"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.mapProviderStatusToInternal = mapProviderStatusToInternal;
function mapProviderStatusToInternal(type) {
    switch (type) {
        case "sent":
            return "sent";
        case "delivered":
            return "delivered";
        case "deferred":
            return "deferred";
        case "bounced":
            return "bounced";
        case "complained":
            return "complained";
        case "opened":
            return "opened";
        case "clicked":
            return "clicked";
        case "unsubscribed":
            return "unsubscribed";
        case "dropped":
            return "dropped";
        default:
            return "unknown";
    }
}
//# sourceMappingURL=mapper.js.map