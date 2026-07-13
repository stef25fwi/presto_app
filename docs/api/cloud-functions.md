# Catalogue des Cloud Functions

Source de référence : `functions/src/index.ts`. Ce document regroupe les exports par domaine ; toute Function ajoutée ou retirée doit mettre à jour les tests, permissions, observabilité et cette documentation.

## Authentification

- triggers : `onUserCreated`, `onUserUpdated`, `onAuthUserCreated`, `onUserRolesChanged` ;
- compte : `requestAccountDeletion`, `syncMyEmailVerification` ;
- emails et sécurité : `requestPasswordResetEmail`, `requestEmailVerificationEmail`, `requestLoginOtpEmail`, `reportPasswordChanged`, `trackUserLogin` ;
- administration : `adminGetAccessStatus`, `getMyAdminAccessStatus`, `adminGetUserStats`, `getUserPresenceStatus`.

## IA, lieux et publication héritée

- `placesAutocomplete`, `placesDetails` ;
- `generateOfferDraft` ;
- `openAiExtractListingFields` ;
- `openAiTranscribeListingAudio` ;
- `openAiExtractListingFieldsFromAudio` ;
- `microIaProcessAudio` ;
- `adminGetMicroIaConfig`, `adminSetMicroIaConfig`.

## Marketplace et annonces

- triggers : `onListingPublished`, `onOfferCreated`, `onOfferUpdated` ;
- brouillons/publication : `createListingDraft`, `updateListingDraftMedia`, `submitListingDraft` ;
- consultation : `incrementListingView`, `getListingContactPhone` ;
- cycle de vie : `deleteListing`, `closeOfferWithReason` ;
- médias : `processOfferPhoto`, `classifyServicePhoto` ;
- signalement : `reportListing` ;
- avis V1 compatibles : `getEligibleRespondersForReview`, `submitVerifiedReview`, `getUserTrustScore`, `reportReview`, `replyToReview` ;
- avis V2 réciproques : `submitMutualVerifiedReview`, `getUserTrustScoreV2`, `reportReviewV2`, `replyToReviewV2`, `publishMaturedReviewsV2` ;
- modération avis V2 : `adminModerateReviewV2` ;
- favoris : `toggleFavorite` ;
- chat marketplace : `createChatThreadFromListing`, `sendChatMessage` ;
- administration : `applyUserRoleClaims`, `logAdminAction`, `reviewListingPhoto` ;
- notifications : `notifyListingApproved`, `notifyListingRejected` ;
- tâches : expiration, publication approuvée, nettoyage Storage et brouillons abandonnés.

### Avis V2 et Score Confiance

Le système V2 conserve la compatibilité avec les anciens champs `trustScore`, mais ajoute `trustScoreV2` sur `users/{uid}` :

- `provider` : score quand l’utilisateur est noté comme prestataire/répondant ;
- `requester` : score quand l’utilisateur est noté comme annonceur/client ;
- `global` : score sur 100, moyenne fiable et statut de profil vérifié.

Les avis V2 sont vérifiés par annonce + conversation et utilisent `reviewerRole` / `reviewedRole` (`requester` ou `provider`). La publication est réciproque : l’avis passe en `published` quand les deux côtés ont noté, ou automatiquement après la fenêtre de 14 jours via `publishMaturedReviewsV2`. Les signalements V2 masquent immédiatement l’avis en `disputed` le temps de la modération.

`adminModerateReviewV2` permet aux rôles `moderator`, `admin` et `superadmin` de décider explicitement : `publish`, `hide`, `reject` ou `request_correction`. Chaque décision est journalisée dans `review_moderation_actions` et notifiée aux utilisateurs concernés. Une mauvaise note seule ne déclenche aucun bannissement automatique ; la modération agit sur l’avis, pas sur le compte.

## Messagerie

- trigger : `onConversationSubMessageCreated` ;
- callables : `ensureOfferConversation`, `sendConversationMessage`, `markConversationRead`, `archiveConversation`, `unarchiveConversation`, `blockConversation`, `unblockConversation`, `adminUnblockConversation`, `deleteConversation`, `deleteConversationMessage`, `processConversationAttachmentPhoto` ;
- tâches : `enqueueUnreadMessageReminders`, `syncMessagingAnalytics`.

## Notifications

- `registerPushToken`, `unregisterPushToken` ;
- `broadcastTestNotification`, `sendSelfTestNotification` ;
- triggers `onNotificationCreated`, `onNotificationUpdated`.

## Billing Stripe

- triggers : `onSubscriptionUpdated`, `onBillingInvoiceUpdated` ;
- callables : `createSubscriptionCheckoutSession`, `getSubscriptionCheckoutStatus`, `createSubscriptionPortalSession`, `auditStripeCatalog` ;
- webhook : `handleStripeWebhook`.

Le webhook signé est autoritaire pour les droits, renouvellements, impayés, résiliations et factures.

## Email et marketing

- onboarding, proximité, profil incomplet et réactivation ;
- `sendReferralInviteEmail` ;
- triggers newsletter ;
- file email : création, traitement, digests, retry et nettoyage ;
- webhook fournisseur : `handleEmailProviderWebhook` ;
- tâches de purge et analytics email.

## Modération, support et légal

- `onSupportTicketCreated`, `onSupportTicketReplied` ;
- `onReportCreated`, `onReportUpdated` ;
- `moderateNewOffer` ;
- `onLegalTermsSettingsUpdated`, `onLegalPrivacySettingsUpdated`.

## Professionnels et administration

- `verifySiret`, `preVerifySiret` ;
- `generatePaymentInfoAudio` ;
- workflow brouillon audio : `generatePaymentInfoAudioDraft`, `publishPaymentInfoAudioDraft`.

## Exigences communes

Chaque callable doit préciser et tester :

- authentification requise ou accès public explicite ;
- App Check selon le risque ;
- rôles et portée ;
- validation et limites des entrées ;
- idempotence ;
- timeout, mémoire et concurrence ;
- codes d’erreur stables ;
- logs structurés sans PII ;
- métriques de succès, échec et latence ;
- tests unitaires et Emulator Suite ;
- stratégie de retry et compensation.

## Région

La région et les secrets communs sont configurés par `setGlobalOptions` via `PROJECT_REGION` et `EMAIL_PROVIDER_SECRETS`. Toute Function nécessitant des secrets supplémentaires doit les déclarer explicitement et ne jamais les renvoyer au client.
