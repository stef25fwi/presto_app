# Marketplace V2

## A. Architecture globale

Marketplace V2 est maintenant la source canonique des annonces publiques. Le flux legacy `offers` reste seulement pour quelques compatibilites de detail ou de messagerie, plus pour la navigation publique catalogue.

- Les brouillons sont ecrits par le client dans `listingDrafts`.
- La publication passe exclusivement par la Cloud Function `submitListingDraft`.
- La fonction applique validation, rate limiting, reCAPTCHA, signaux anti-abus et moderation avant d'ecrire `listings`.
- Les collections sensibles restent en ecriture serveur seule: `listings`, `listingModeration`, `listingReports`, `favorites`, `chatThreads`, `adminActions`, `analyticsSnapshots`.
- Le client Flutter appelle des callables pour les mutations critiques et lit Firestore seulement sur les vues autorisees.
- La messagerie marketplace est separee de la messagerie legacy et stockee dans `chatThreads/{threadId}/messages/{messageId}`.
- Les roles sont portes par les custom claims Firebase Auth via `roles`, `primaryRole` et `marketplaceAccess`.

Flux principal:

1. L'utilisateur cree ou met a jour un brouillon.
2. Le client upload les images dans Storage sur le namespace brouillon.
3. `submitListingDraft` valide et soumet le brouillon.
4. La moderation automatique attribue un score de risque et une decision initiale.
5. La publication finale alimente `listings` avec un etat `active`, `pending` ou `rejected`.
6. Les notifications, favoris, signalements, analytics et chat s'appuient ensuite sur cet identifiant d'annonce.

## B. Schema Firestore detaille

Collections principales:

- `users/{uid}`: statut compte, roles, score spam, confiance vendeur, metriques de securite.
- `profiles/{uid}`: profil public simplifie, nom affiche, avatar, ville, marqueur pro.
- `listingDrafts/{draftId}`: brouillons edites par leur proprietaire.
- `listings/{listingId}`: annonce publiee ou en attente, ecriture serveur seule.
- `listingModeration/{listingId}`: verdicts auto/manuels, flags, scans, score de risque.
- `listingReports/{reportId}`: signalements utilisateur et resolution moderation.
- `favorites/{favoriteId}`: relation user <-> annonce, ecriture serveur seule.
- `chatThreads/{threadId}`: fil de discussion marketplace, participants, compteurs, blocages.
- `chatThreads/{threadId}/messages/{messageId}`: messages du thread.
- `adminActions/{actionId}`: journal d'audit des actions moderateur/admin.
- `categories/{categoryId}` et `cities/{cityId}`: referentiels actifs.
- `analyticsSnapshots/{snapshotId}`: agrégats journaliers backend.
- `appConfig/marketplace`: seuils moderation et anti-spam centralises.

Champs structurants d'une annonce `listings/{listingId}`:

- `ownerId`, `title`, `description`, `price`, `categoryId`, `cityId`
- `media[]`, `thumbnailUrl`
- `status`: `draft|pending|active|rejected|archived|sold|deleted`
- `moderationStatus`: `pending|auto_flagged|approved|rejected|manual_review|blocked`
- `visibility`: `private|public|hidden`
- `reportCount`, `favoriteCount`, `viewCount`, `contactCount`
- `isBoosted`, `boostExpiresAt`, `publishedAt`, `expiresAt`
- `searchKeywords`, `locationApprox`, `sourceDraftId`, `riskScore`

## C. Roles et securite

Roles supportes:

- `user`
- `moderator`
- `admin`
- `superadmin`
- `pro`

Principes:

- Les privileges elevés reposent sur les custom claims et non sur des flags modifiables client.
- `applyUserRoleClaims` synchronise les claims propres tout en conservant la compatibilite avec des claims legacy booleens.
- Les documents `users` et `profiles` bloquent en regles les champs critiques de role et de moderation.
- Les mutations sensibles passent uniquement par Cloud Functions.
- Le backend journalise les actions admins dans `adminActions`.

## D. Regles Firestore et Storage

Firestore:

- Lecture publique limitee aux annonces `active` + `public`.
- Proprietaire autorise sur ses brouillons et la lecture de ses objets de moderation.
- Moderateurs/admins autorises en lecture sur moderation, reports, admin actions et analytics.
- `favorites`, `listingReports`, `listings`, `chatThreads/messages`, `adminActions` sont verrouilles en ecriture client.

Storage:

- `listingDrafts/{uid}/{draftId}/{fileName}`: lecture/ecriture uniquement par le proprietaire, types image, taille plafonnee.
- `listings/{uid}/{listingId}/{fileName}`: lecture publique uniquement si l'annonce associee est `active` + `public`, sinon proprietaire ou moderation.
- L'ecriture finale sur l'espace annonce publiee reste serveur seule.

## E. Cloud Functions a creer

Callables marketplace exportees:

- `submitListingDraft`
- `incrementListingView`
- `reportListing`
- `toggleFavorite`
- `createChatThreadFromListing`
- `sendChatMessage`
- `applyUserRoleClaims`
- `logAdminAction`

Triggers et jobs:

- `notifyListingApproved`
- `notifyListingRejected`
- `expireOldListings`

## F. Pipeline moderation

Pipeline implemente:

1. Validation stricte du payload et des medias.
2. Verification reCAPTCHA Enterprise avec bypass local/emulator.
3. Chargement du referentiel categorie/ville actif.
4. Construction de signaux proprietaire: spam score, strikes, frequence de publication, doublons proches.
5. Analyse texte et media via le service de moderation.
6. Calcul d'une decision `approved`, `manual_review` ou `rejected` selon les flags et le score de risque.
7. Persistance du resultat dans `listingModeration` et projection finale dans `listings`.

Le pipeline supporte un modele hybride: auto-approve pour contenu propre, file manuelle pour cas douteux, rejection directe pour abus clairs.

## G. Pipeline analytics

Deux couches:

- Client Flutter via `ProductAnalyticsService` pour les evenements UX.
- Backend via `trackProductEventBackend` pour les evenements de verite metier.

Evenements principaux:

- `listing_create_started`
- `listing_create_completed`
- `listing_submitted`
- `listing_published`
- `listing_rejected`
- `listing_view`
- `listing_favorite_added`
- `listing_favorite_removed`
- `listing_message_started`
- `listing_reported`

Le backend alimente aussi `analyticsSnapshots` pour des tableaux de bord simples et peu couteux.

## H. Client Flutter a brancher

Couche client ajoutee:

- Modeles: enums, draft, listing, report.
- Repositories: listing, favorite, report, chat.
- Services: analytics produit et Remote Config marketplace.

Branchement attendu dans les ecrans:

- Ecran creation/edition annonce vers `ListingRepository.createDraft/updateDraft/submitDraft`.
- Ecran detail annonce vers `incrementView`, `toggleFavorite`, `createThreadFromListing`.
- Ecran signalement vers `reportListing`.
- Activation progressive des features via Remote Config.

## I. Perf, couts et monitoring

Choix de maitrise des couts:

- compteurs denormalises sur `listings`
- indexes composites cibles sur les vraies vues produit
- rate limiting backend `_rate_limits`
- agrégats journaliers `analyticsSnapshots`
- ecriture serveur seule sur les parcours critiques pour eviter les incoherences de recomptage

Monitoring recommande:

- logs structures via `logger`
- alarmes sur taux de rejection, manual review, reports, view spikes
- Crashlytics/Performance/Analytics cote Flutter
- revue periodique des seuils dans `appConfig/marketplace`

## J. Plan d'implementation

Phase 1:

- activer creation de brouillon + soumission backend + moderation + lecture publique.

Phase 2:

- brancher favoris, signalements, chat marketplace et notifications associees.

Phase 3:

- brancher panneaux moderation/admin et workflows manuels.

Phase 4:

- migration publique `offers` vers `listings` terminee pour les ecrans catalogue.
- conserver uniquement les compatibilites legacy encore necessaires hors catalogue public.

## K. Liste des fichiers a creer ou modifier

Backend principal:

- `functions/src/modules/marketplace/constants/enums.ts`
- `functions/src/modules/marketplace/models/firestore.ts`
- `functions/src/modules/marketplace/validators/listings.ts`
- `functions/src/modules/marketplace/services/moderation.ts`
- `functions/src/modules/marketplace/services/roles.ts`
- `functions/src/modules/marketplace/services/recaptcha.ts`
- `functions/src/modules/marketplace/services/analytics.ts`
- `functions/src/modules/marketplace/services/admin_audit.ts`
- `functions/src/modules/marketplace/callables/listings.ts`
- `functions/src/modules/marketplace/callables/reports.ts`
- `functions/src/modules/marketplace/callables/favorites.ts`
- `functions/src/modules/marketplace/callables/chat.ts`
- `functions/src/modules/marketplace/callables/admin.ts`
- `functions/src/modules/marketplace/triggers/notifications.ts`
- `functions/src/modules/marketplace/scheduled/listings.ts`
- `functions/src/index.ts`
- `functions/src/shared/constants.ts`
- `functions/package.json`

Securite et infra:

- `firestore.rules`
- `storage.rules`
- `firestore.indexes.json`
- `.vscode/tasks.json`

Flutter:

- `lib/models/marketplace_enums.dart`
- `lib/models/marketplace_listing_draft.dart`
- `lib/models/marketplace_listing.dart`
- `lib/models/marketplace_report.dart`
- `lib/data/marketplace/listing_repository.dart`
- `lib/data/marketplace/favorite_repository.dart`
- `lib/data/marketplace/report_repository.dart`
- `lib/data/marketplace/chat_repository.dart`
- `lib/services/product_analytics_service.dart`
- `lib/services/marketplace_remote_config_service.dart`
- `test/marketplace_models_test.dart`

Notes d'integration:

- La couche messaging legacy reste en place et a ete durcie en parallele.
- `toggleFavorite` ecrit aussi dans `users/{uid}/favoriteOffers/{listingId}` pour la compatibilite actuelle.
- `COLLECTIONS.listingDraftsV2` pointe volontairement vers la collection Firestore `listingDrafts` pour le client Flutter.
- Les ecrans publics Accueil et Je consulte lisent desormais `listings` uniquement avec le contrat `status == active && visibility == public`.
- Sur le web, une absence de `APPCHECK_RECAPTCHA_SITE_KEY` ne doit pas bloquer la lecture publique Firestore; elle place seulement le bootstrap App Check en mode skip/monitoring tant qu'aucun enforce n'est requis pour cette lecture.