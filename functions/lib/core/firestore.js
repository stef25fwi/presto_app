"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.fs = exports.db = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
if (firebase_admin_1.default.apps.length === 0) {
    firebase_admin_1.default.initializeApp();
}
exports.db = firebase_admin_1.default.firestore();
exports.fs = firebase_admin_1.default.firestore;
//# sourceMappingURL=firestore.js.map