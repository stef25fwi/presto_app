"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.writeAdminActionLog = writeAdminActionLog;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
async function writeAdminActionLog({ actorId, actorRole, actionType, targetType, targetId, before, after, metadata, }) {
    const ref = firestore_1.db.collection(constants_1.COLLECTIONS.adminActions).doc();
    await ref.set({
        id: ref.id,
        actorId,
        actorRole,
        actionType,
        targetType,
        targetId,
        before: before ?? null,
        after: after ?? null,
        metadata: metadata ?? {},
        createdAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    });
    logger_1.logger.info("marketplace_admin_action_logged", {
        adminActionId: ref.id,
        actorId,
        actorRole,
        actionType,
        targetType,
        targetId,
    });
    return ref.id;
}
//# sourceMappingURL=admin_audit.js.map