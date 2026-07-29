# Preuve — App Check appliqué à Cloud Storage

**Contrôle** : `app-check-storage-enforced`
**Nature** : `external-evidence` — réglage de console Firebase, hors de portée du dépôt.
**Statut au 2026-07-29 : `pending`.**

Comme pour Firestore, l'état « Enforce » de Cloud Storage vit dans la console
Firebase et n'est exposé par aucun artefact versionné. Ce contrôle exige une
vérification humaine avec accès au projet `presto-app-74abe`.

## Procédure de vérification

1. Console Firebase → projet `presto-app-74abe` → **App Check** → onglet
   **APIs** → ligne **Cloud Storage**.
2. Relever l'état : `Enforced`, `Unenforced` ou `Monitoring`.
3. Contrôler dans **Metrics** que la part de requêtes *Verified* est proche de
   100 % sur 7 jours avant toute bascule.
4. Vérifier que les fournisseurs d'attestation sont actifs pour les trois
   plateformes (reCAPTCHA Enterprise, Play Integrity, App Attest).

## Point d'attention propre à ce dépôt

Storage porte les médias d'annonces et les visuels `hero_slides/`. Les règles
`storage.rules` sont versionnées : les relire conjointement à cette
vérification, en particulier les chemins ouverts en lecture publique, qui
resteront lisibles indépendamment d'App Check.

Le parcours de publication téléverse depuis le client web ; la même réserve que
pour Firestore s'applique — vérifier que le SDK web attache bien le jeton App
Check aux requêtes Storage avant de basculer sur `Enforced`, sous peine de
casser la publication d'annonces.

## Clôture

Une fois `Enforced` constaté et une capture datée jointe à ce document, passer
`app-check-storage-enforced` à `"status": "verified"` dans
`quality/security-controls.json`.

| Date | Vérifié par | État constaté | Capture |
|---|---|---|---|
| _à compléter_ | | | |
