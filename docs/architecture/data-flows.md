# Flux techniques critiques

## Authentification et App Check

```mermaid
sequenceDiagram
  participant U as Utilisateur
  participant F as Flutter
  participant A as Firebase Auth
  participant C as Cloud Functions
  participant D as Firestore

  U->>F: Connexion Email / Google / Apple
  F->>A: Authentification
  A-->>F: ID token
  F->>C: Callable + ID token + App Check
  C->>C: Vérifie Auth, App Check et rôle
  C->>D: Lecture/écriture autorisée
  C-->>F: Résultat normalisé
```

Règles :

- les rôles autoritaires sont les custom claims et les documents backend synchronisés ;
- le client ne peut jamais s’attribuer un rôle, un abonnement ou un droit ;
- les erreurs exposées au client utilisent des codes stables sans détail sensible ;
- la suppression de compte passe par `requestAccountDeletion` et une procédure backend traçable.

## Publication d’une annonce

```mermaid
sequenceDiagram
  participant U as Utilisateur
  participant F as Flutter
  participant S as Storage
  participant C as Cloud Functions
  participant D as Firestore
  participant M as Modération

  U->>F: Saisie ou dictée
  F->>C: IA/transcription facultative
  C-->>F: Brouillon de champs
  F->>C: createListingDraft
  C->>D: Brouillon privé
  F->>S: Médias autorisés
  F->>C: updateListingDraftMedia
  F->>C: submitListingDraft + reCAPTCHA/App Check
  C->>M: Validation et modération
  M->>D: Statut pending/approved/rejected
  D-->>F: État observable
```

Garanties : validation backend, quota d’abonnement backend, médias contrôlés, idempotence de soumission, journalisation de la modération et absence de publication directe depuis le client.

## Consultation, favoris et contact

```mermaid
flowchart LR
  A[Requête publique bornée] --> B[Tri stable + limit]
  B --> C[Page de résultats]
  C --> D[Détail]
  D --> E[toggleFavorite callable]
  D --> F[getListingContactPhone callable]
  D --> G[Conversation]
```

Les listes publiques sont bornées et doivent évoluer vers une pagination par curseur. Le téléphone n’est retourné que par callable lorsque les règles métier l’autorisent.

## Messagerie

```mermaid
sequenceDiagram
  participant F as Flutter
  participant C as Callable
  participant D as Firestore
  participant N as Notifications

  F->>C: ensureOfferConversation
  C->>D: Crée ou réutilise la conversation
  F->>C: sendConversationMessage
  C->>D: Écrit le message et les compteurs
  D->>N: Trigger message créé
  N-->>F: Push/email selon préférences
  F->>C: markConversationRead
```

Les messages sont écrits côté backend, paginés, associés à une conversation autorisée et soumis aux règles de blocage/modération.

## Abonnement Stripe

```mermaid
sequenceDiagram
  participant U as Utilisateur
  participant F as Flutter
  participant C as Cloud Functions
  participant S as Stripe
  participant D as Firestore

  U->>F: Choisit un plan
  F->>C: createSubscriptionCheckoutSession
  C->>S: Crée ou réutilise la session
  S-->>C: URL checkout Stripe
  C-->>F: URL HTTPS validée et expiration
  F->>S: Ouvre checkout
  S->>C: handleStripeWebhook signé
  C->>D: Met à jour abonnement et facture
  D-->>F: Droits recalculés
```

Le retour navigateur ne prouve jamais le paiement. Seul un webhook Stripe signé ou une vérification backend met à jour les droits.

## Suppression administrative et historique

```mermaid
flowchart TD
  A[Sélection simple ou multiple] --> B[Callable admin autorisée]
  B --> C{Validation rôle et portée}
  C -->|Refus| D[Erreur auditée]
  C -->|Autorisé| E[Snapshot historique]
  E --> F[Suppression logique / archivage]
  F --> G[Mise à jour agrégats actifs]
  G --> H[Journal admin immuable côté client]
```

Une donnée supprimée disparaît des listes et statistiques actives, mais son résumé, l’auteur de l’action, la date et le motif restent disponibles dans l’historique autorisé.