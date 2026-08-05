import admin from "./firebase_admin_compat";

let firestoreInstance: FirebaseFirestore.Firestore | null = null;

function ensureAdminApp(): admin.app.App {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  return admin.initializeApp();
}

export function getDb(): FirebaseFirestore.Firestore {
  if (firestoreInstance != null) {
    return firestoreInstance;
  }

  ensureAdminApp();
  firestoreInstance = admin.firestore();
  return firestoreInstance;
}

export const db = new Proxy({} as FirebaseFirestore.Firestore, {
  get(_target, property, receiver) {
    const instance = getDb();
    const value = Reflect.get(instance as object, property, receiver);
    return typeof value === "function" ? value.bind(instance) : value;
  },
}) as FirebaseFirestore.Firestore;

export function fs(): FirebaseFirestore.Firestore {
  return getDb();
}
