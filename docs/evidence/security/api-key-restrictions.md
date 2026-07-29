# Preuve — clés API restreintes

**Contrôle** : `api-keys-restricted`
**Nature** : `external-evidence` — réglage de console Google Cloud, hors de portée du dépôt.
**Statut au 2026-07-29 : `pending`.**

Les restrictions de clés API vivent dans Google Cloud Console
(*APIs & Services → Credentials*) et ne sont exposées par aucun artefact
versionné. Ce contrôle exige une vérification humaine avec accès au projet
`presto-app-74abe`.

## Pourquoi ce contrôle est nécessaire

Les clés `AIzaSy…` présentes dans `lib/firebase_options.dart`,
`android/app/google-services.json` et `web/firebase-messaging-sw.js` sont des
identifiants **publics** de projet Firebase : elles sont livrées dans le bundle
web et l'APK, et leur présence au dépôt est normale. Elles n'authentifient
personne — l'autorisation vient de Firebase Auth et des règles de sécurité.

Elles restent toutefois un vecteur d'abus de quota et de facturation si elles
ne sont pas restreintes. C'est la restriction, et non le secret, qui les
protège.

## Procédure de vérification

Pour chaque clé du projet `presto-app-74abe` :

1. **Restriction d'application** :
   - clé Web → *HTTP referrers*, limitée aux domaines servis
     (`ilipresto.fr`, `*.ilipresto.fr`, plus les domaines Firebase Hosting) ;
   - clé Android → *Android apps*, avec nom de package **et** empreinte SHA-1
     du certificat de signature de release ;
   - clé iOS → *iOS apps*, avec le bundle ID.
2. **Restriction d'API** : ne cocher que les API réellement utilisées
   (Identity Toolkit, Firestore, Storage, FCM, Firebase Installations…) et
   jamais *Don't restrict key*.
3. Vérifier qu'aucune clé non restreinte ne subsiste, y compris les clés
   héritées et créées automatiquement.
4. Contrôler dans *Metrics* qu'aucune clé ne présente de pic de trafic
   inexpliqué.

## Clôture

Une fois les restrictions constatées et une capture datée jointe à ce document,
passer `api-keys-restricted` à `"status": "verified"` dans
`quality/security-controls.json`.

| Clé | Type de restriction | API restreintes | Date | Vérifié par |
|---|---|---|---|---|
| _à compléter_ | | | | |
