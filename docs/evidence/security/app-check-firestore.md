# Preuve — App Check appliqué à Cloud Firestore

**Contrôle** : `app-check-firestore-enforced`
**Nature** : `external-evidence` — réglage de console Firebase, hors de portée du dépôt.
**Statut au 2026-07-29 : `pending`.**

Ce contrôle ne peut pas être fermé depuis le dépôt ni depuis la CI : l'état
« Enforce » de Firestore vit dans la console Firebase et n'est exposé par aucun
artefact versionné. Il exige une vérification humaine avec accès au projet
`presto-app-74abe`.

## Procédure de vérification

1. Ouvrir la console Firebase → projet `presto-app-74abe` → **App Check** →
   onglet **APIs**.
2. Relever l'état de la ligne **Cloud Firestore** : `Enforced`, `Unenforced` ou
   `Monitoring`.
3. Avant de basculer sur `Enforced`, contrôler dans l'onglet **Metrics** que la
   part de requêtes *Verified* est proche de 100 % sur 7 jours glissants. Une
   bascule avec un volume significatif de requêtes non vérifiées coupe l'accès
   aux clients légitimes non encore attestés.
4. Vérifier que chaque plateforme dispose d'un fournisseur d'attestation actif :
   reCAPTCHA Enterprise (Web), Play Integrity (Android), App Attest (iOS).

## Point d'attention propre à ce dépôt

`firestore.rules` documente que `hasAppCheck()` a été volontairement retiré des
règles d'écriture de `users/{userId}` : le SDK Flutter Web n'attache pas de
jeton App Check aux requêtes Firestore (seulement aux Cloud Callables). La
sécurité de cette collection repose donc sur `isSignedIn()`, le contrôle de
propriétaire et la liste `protectedUserFields()`.

Conséquence directe : passer Firestore en `Enforced` **cassera le client web**
tant que ce SDK n'attache pas de jeton. Cette vérification doit précéder la
bascule, et l'ordre correct est :

1. confirmer que le SDK Flutter Web utilisé attache bien le jeton App Check à
   Firestore ;
2. observer les métriques `Verified` en mode `Monitoring` ;
3. puis seulement basculer sur `Enforced`.

## Clôture

Une fois `Enforced` constaté et une capture datée jointe à ce document, passer
`app-check-firestore-enforced` à `"status": "verified"` dans
`quality/security-controls.json`.

| Date | Vérifié par | État constaté | Capture |
|---|---|---|---|
| _à compléter_ | | | |
