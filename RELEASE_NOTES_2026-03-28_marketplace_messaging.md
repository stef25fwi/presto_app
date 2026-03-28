# Release Notes - 2026-03-28

## Resume executif

Cette livraison consolide deux chantiers majeurs:

- la remise a niveau complete de la messagerie legacy pour garantir l'ouverture et la visibilite des conversations dans la page Messages
- l'introduction du socle Marketplace V2 avec publication securisee, signalement, favoris, moderation, analytics produit et nouvelles APIs backend

Statut de livraison:

- code pousse sur `main`
- build Flutter web OK
- build Functions OK
- deploiement Firebase OK sur `presto-app-74abe`
- analyse Flutter OK
- tests backend Functions OK

## Changements fonctionnels cote utilisateur

### Messagerie

- Depuis une annonce, le bouton "Envoyer un message" redirige maintenant vers la page Messages, puis ouvre automatiquement la bonne conversation.
- Le brouillon initial de prise de contact est conserve jusqu'au thread de conversation.
- Les conversations ciblées par notification s'ouvrent de facon fiable dans la page Messages.
- La liste Messages reste compatible avec les metadonnees legacy de conversation grace a la lecture des alias participants / participant_ids.

### Consultation d'annonce

- Les ecrans de detail savent ouvrir la messagerie de facon coherente au lieu d'ouvrir un thread isole hors du flux principal.
- Les deep links de conversations et des annonces Marketplace sont mieux raccordes au routage applicatif.

### Marketplace V2

- Publication d'annonce Marketplace via un service dedie et une soumission backend securisee.
- Ajout du signalement Marketplace depuis la fiche detail.
- Ajout des favoris Marketplace sur la fiche detail.
- Support du partage des URLs de listing.
- Support du reCAPTCHA Enterprise mobile et web pour les actions sensibles Marketplace.

## Changements techniques majeurs

### Flutter

- Ajout d'une couche de publication Marketplace dediee.
- Ajout d'une couche de verification humaine cross-platform.
- Ajout du routage listing et de l'ouverture automatique de conversation ciblee.
- Ajout de la prise en charge des payloads Marketplace dans la page detail annonce.
- Mise a jour iOS vers un minimum cible 15.0 pour la compatibilite reCAPTCHA Enterprise.

### Backend Functions

- Ajout du fallback offre ou listing pour la creation de conversation legacy.
- Ajout des callables Marketplace V2.
- Ajout de la moderation Marketplace, de la logique analytics et de la verification reCAPTCHA.
- Ajout de seeds bootstrap pour categories, villes et configuration Marketplace.

## APIs backend ajoutees ou etendues

### Nouvelles APIs Marketplace

- `submitListingDraft`
- `incrementListingView`
- `reportListing`
- `toggleFavorite`
- `createChatThreadFromListing`
- `sendChatMessage`
- `applyUserRoleClaims`
- `logAdminAction`
- `expireOldListings`

### APIs legacy messagerie ameliorees

- `ensureOfferConversation`
  - accepte maintenant une annonce issue de `offers` ou de `listings`
- `sendConversationMessage`
- `markConversationRead`
- `archiveConversation`
- `unarchiveConversation`
- `blockConversation`
- `unblockConversation`
- `deleteConversation`
- `deleteConversationMessage`

## Donnees, regles et configuration

- Mise a jour des regles Firestore.
- Mise a jour des regles Storage.
- Mise a jour des indexes Firestore.
- Ajout des seeds Marketplace:
  - categories
  - appConfig marketplace
  - villes

## Validation effectuee

- Flutter analyze: OK
- Flutter build web release: OK
- Functions build: OK
- Functions tests: OK
- Firebase deploy: OK

## Impacts produit

- La messagerie redevient un flux central et coherent depuis les annonces.
- Les conversations sont plus faciles a retrouver et a rouvrir.
- Le socle Marketplace V2 est desormais exploitable avec publication, signalement et engagement utilisateur.
- Le produit dispose maintenant d'APIs plus propres pour evoluer vers des parcours moderes et mesures.

## Fichiers de reference

- [RELEASE_NOTES_2026-03-28_marketplace_messaging.md](RELEASE_NOTES_2026-03-28_marketplace_messaging.md)
- [docs/marketplace_v2_architecture.md](docs/marketplace_v2_architecture.md)
- [lib/pages/messages/conversations_list_page.dart](lib/pages/messages/conversations_list_page.dart)
- [lib/pages/offers/offer_details_page.dart](lib/pages/offers/offer_details_page.dart)
- [functions/src/modules/messaging/callables.ts](functions/src/modules/messaging/callables.ts)
- [functions/src/modules/marketplace/callables/listings.ts](functions/src/modules/marketplace/callables/listings.ts)

## Post-release recommande

- verifier manuellement le parcours complet depuis une annonce legacy jusqu'a la page Messages
- verifier manuellement le parcours complet depuis une annonce Marketplace jusqu'a la page Messages
- verifier les notifications push et la cloche in-app sur un compte expediteur et un compte destinataire
- lancer le bootstrap seed Marketplace sur l'environnement cible si ce n'est pas deja fait