"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.db = void 0;
exports.getDb = getDb;
exports.fs = fs;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
let firestoreInstance = null;
function ensureAdminApp() {
    if (firebase_admin_1.default.apps.length > 0) {
        return firebase_admin_1.default.app();
    }
    return firebase_admin_1.default.initializeApp();
}
function getDb() {
    if (firestoreInstance != null) {
        return firestoreInstance;
    }
    ensureAdminApp();
    firestoreInstance = firebase_admin_1.default.firestore();
    return firestoreInstance;
}
exports.db = new Proxy({}, {
    get(_target, property, receiver) {
        const instance = getDb();
        const value = Reflect.get(instance, property, receiver);
        return typeof value === "function" ? value.bind(instance) : value;
    },
});
function fs() {
    return getDb();
}
//# sourceMappingURL=firestore.js.map