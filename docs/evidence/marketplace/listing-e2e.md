# Preuve E2E — Marketplace d’annonces

## Chaîne certifiée

1. Le client appelle `createListingDraft`.
2. Le backend remplace l’identité par l’UID authentifié, filtre les champs et valide le schéma.
3. Les photos passent par Storage, `processOfferPhoto` et `updateListingDraftMedia`.
4. `submitListingDraft` contrôle propriétaire, catégorie, ville, quotas, fréquence, reCAPTCHA, doublons et risque.
5. La publication dépend exclusivement de la décision serveur et de la modération.
6. Les états pending, rejected, active et archived sont gérés dans le compte.
7. Un échec avant soumission nettoie les médias ; une relecture post-soumission en échec ne supprime jamais les médias publiés.

## Fonctions certifiées

- brouillons et validation serveur ;
- médias et nettoyage ;
- soumission et modération ;
- consultation et filtres ;
- favoris transactionnels ;
- téléphone protégé ;
- signalements et avis ;
- cycle de vie complet.

## Commandes

`flutter analyze --fatal-infos`
`flutter test --coverage --reporter expanded`
`npm --prefix functions test`
`npm --prefix functions run test:firestore`
`node tools/quality/check_marketplace_readiness.mjs --enforce`
