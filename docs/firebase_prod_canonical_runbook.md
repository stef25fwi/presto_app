# Firebase Prod Canonical Runbook

## Objet

Runbook court pour exploiter l'architecture canonique actuelle de presto_app sans reouvrir les chemins legacy en ecriture.

## Collections et chemins canoniques

- Firestore annonces: listings
- Firestore brouillons: listingDrafts
- Firestore utilisateurs: users
- Firestore conversations: conversations/{conversationId}/messages/{messageId}
- Storage brut: listingDrafts/{uid}/{draftId}/{fileName}
- Storage final: listings/{uid}/{listingId}/{fileName}

## Regle d'exploitation

- Toutes les mutations critiques passent par Cloud Functions.
- Le client lit Firestore directement seulement pour les vues autorisees.
- Les collections legacy offers, profiles et listing_drafts sont en lecture/compat seulement.
- La sous-collection legacy users/{uid}/favoriteOffers est en lecture seule pendant la migration vers favorites.
- Les favoris canoniques sont dans favorites.

## Validations a lancer

- Flutter analyse: tâche VS Code shell: Flutter: Analyze
- Flutter tests ciblés: tâche VS Code shell: Flutter: Test conversation state
- Functions build: tâche VS Code shell: Functions: Build
- Functions tests: tâche VS Code shell: Functions: Test
- Rules publiques listings: npm --prefix functions run test:firestore:public-listings
- Rules canoniques fail-closed: firebase emulators:exec --project presto-app-74abe "node functions/scripts/test_canonical_marketplace_rules.mjs"

## Scripts opératoires

- Audit collections: npm --prefix functions run marketplace:audit:collections
- Seed taxonomy dry-run: npm --prefix functions run marketplace:seed:taxonomy:dry-run
- Seed taxonomy apply: npm --prefix functions run marketplace:seed:taxonomy
- Migration offers dry-run: npm --prefix functions run marketplace:migrate:offers-to-listings:v2:dry-run
- Migration favorites dry-run: npm --prefix functions run marketplace:migrate:favorites:dry-run
- Migration profiles dry-run: npm --prefix functions run marketplace:migrate:profiles:dry-run

## Limites connues de test

- Le package local @firebase/rules-unit-testing ne simule pas request.app.
- Les tests emulator couvrent donc proprement les refus sans App Check.
- Les cas allow avec App Check doivent etre verifies par smoke test reel ou via clients instrumentes.

## Reliquats legacy encore volontaires

- Lecture fallback offers pour compat catalogue/detail ancien et enrichissements email.
- Triggers offers legacy encore presents pour la phase de transition.
- Lecture fallback favoriteOffers cote Flutter tant que la migration favorites n'a pas ete appliquee, mais elle est desormais centralisee dans lib/data/marketplace/favorite_repository.dart et toute nouvelle ecriture client est refusee par les regles.
- Fallback lecture Functions encore assumes:
- functions/src/modules/messaging/callables.ts lit d'abord listings et ne replie sur offers que si le listing canonique est absent.
- functions/src/modules/listings/scheduled.ts interroge d'abord listings pour savoir si un utilisateur a deja une annonce publiee, puis ne replie sur offers qu'en absence de publication canonique.
- functions/src/modules/marketing/scheduled.ts compte maintenant uniquement les listings canoniques recents pour les emails de nouvelles annonces proches.
- functions/src/modules/email/events/enrich.ts genere des URLs canoniques pour listings et ne conserve offers que pour enrichir les evenements legacy historiques.
- functions/src/modules/marketplace/scheduled/storage_cleanup.ts et les rappels sur listing_drafts gardent la compat de nettoyage/migration.
- Flutter ne garde plus d'acces direct a offers dans les pages prod courantes; le reliquat restant cote app est le seed dev de home_page, deplace dans lib/dev/seed_offers.dart.

## Sortie de migration ciblee

- Plus aucune nouvelle ecriture dans offers, profiles, listing_drafts.
- Plus aucun nouvel upload sous offers_raw ni offers.
- Les nouveaux favoris partent uniquement dans favorites.
- Les nouvelles conversations utilisent listingId canonique et conversationId hashé conv_.