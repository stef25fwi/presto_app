// Compatibility facade for the canonical Firebase/Firestore contract.
//
// New code should import `core/firebase_contract.dart` directly. This file
// intentionally defines no collection or field names so there is only one
// source of truth for the persisted Firestore schema.
export '../../core/firebase_contract.dart'
    show FirestoreCollections, ListingFields;
