# Checklist email Functions implementees

## Statut global

- [x] Architecture email modulaire typee ajoutee dans `functions/src/modules/email`
- [x] Un fichier TypeScript par template modulaire
- [x] Registre central des templates modulaires
- [x] Couche de compatibilite entre ancien worker et nouveaux templates
- [x] Services partages pour preferences, logs et dispatch
- [x] Branding email aligne avec le logo `assets/images/logowebp.webp`
- [x] Triggers, callables et schedulers relies aux nouveaux evenements email
- [x] Script d'audit post-deploiement ajoute
- [x] Build + tests backend valides

## Fondations email ajoutees

- [x] `functions/src/modules/email/contracts.ts`
- [x] `functions/src/modules/email/services/EmailPreferenceService.ts`
- [x] `functions/src/modules/email/services/EmailLogService.ts`
- [x] `functions/src/modules/email/services/EmailDispatchService.ts`
- [x] `functions/src/modules/email/templates/definitions/shared.ts`
- [x] `functions/src/modules/email/templates/definitions/index.ts`
- [x] `functions/src/modules/email/templates/compat_registry.ts`
- [x] `functions/src/modules/email/examples/firestore_examples.ts`

## Templates modulaires enregistres

- [x] verify_email -> `tpl_transactional_account_email_verification_v2`
- [x] login_otp -> `tpl_transactional_account_login_otp_v1`
- [x] forgot_password -> `tpl_transactional_account_password_forgotten_v2`
- [x] password_changed -> `tpl_transactional_account_password_changed_v2`
- [x] account_deletion_requested -> `tpl_transactional_account_deletion_requested_v1`
- [x] account_deleted -> `tpl_transactional_account_deleted_v1`
- [x] welcome_user -> `tpl_transactional_account_welcome_v2`
- [x] profile_incomplete_reminder -> `tpl_lifecycle_profile_incomplete_reminder_v1`
- [x] account_verified -> `tpl_lifecycle_account_verified_v1`
- [x] listing_under_review -> `tpl_transactional_listing_under_review_v2`
- [x] listing_published -> `tpl_transactional_listing_published_v2`
- [x] listing_rejected -> `tpl_transactional_listing_rejected_v2`
- [x] message_received -> `tpl_transactional_message_received_v2`
- [x] payment_confirmed -> `tpl_transactional_payment_confirmed_v2`
- [x] payment_failed -> `tpl_transactional_payment_failed_v2`
- [x] subscription_renewed -> `tpl_transactional_subscription_renewed_v1`
- [x] subscription_expired -> `tpl_transactional_subscription_expired_v1`
- [x] first_listing_not_published -> `tpl_lifecycle_first_listing_not_published_v1`
- [x] reactivation_30_days -> `tpl_marketing_reactivation_30_days_v1`
- [x] nearby_new_listings -> `tpl_marketing_nearby_new_listings_v1`
- [x] referral_invite -> `tpl_marketing_referral_invite_v1`

Total: 21 templates modulaires.

## Functions exportees qui emettent des email_events

### Auth et compte

- [x] `onUserCreated` -> `user.created`
- [x] `onUserUpdated` -> `profile.verified`
- [x] `onUserUpdated` -> `user.account.deletion.requested`
- [x] `onUserUpdated` -> `user.account.deleted`
- [x] `requestEmailVerificationEmail` -> `user.email_verification.requested`
- [x] `requestPasswordResetEmail` -> `user.password_reset.requested`
- [x] `requestLoginOtpEmail` -> `user.otp.requested`
- [x] `reportPasswordChanged` -> `user.password_changed`
- [x] `trackUserLogin` -> `user.login.suspicious`

### Listings et marketplace

- [x] `onOfferCreated` -> `listing.submitted`
- [x] `onOfferCreated` -> `listing.published`
- [x] `onOfferUpdated` -> `listing.submitted`
- [x] `onOfferUpdated` -> `listing.published`
- [x] `onOfferUpdated` -> `listing.rejected`
- [x] `onListingPublished` -> `listing.published`
- [x] `enqueueFirstListingNotPublishedReminders` -> `listing.first_not_published.reminder`
- [x] `enqueueExpiringListingEmails` -> `listing.expiring_soon`
- [x] `enqueueExpiringListingEmails` -> `listing.expired`

### Messagerie

- [x] `onConversationSubMessageCreated` -> `message.created.new_thread`
- [x] `onConversationSubMessageCreated` -> `message.created.existing_thread`

### Billing

- [x] `onSubscriptionUpdated` -> `subscription.renewal.upcoming`
- [x] `onSubscriptionUpdated` -> `billing.subscription.renewed`
- [x] `onSubscriptionUpdated` -> `billing.subscription.expired`
- [x] `onBillingInvoiceUpdated` -> `billing.payment.succeeded`
- [x] `onBillingInvoiceUpdated` -> `billing.payment.failed`

### Marketing

- [x] `enqueueMarketingOnboardingEmails` -> `marketing.onboarding.d1_due`
- [x] `enqueueMarketingOnboardingEmails` -> `marketing.onboarding.d3_due`
- [x] `enqueueMarketingOnboardingEmails` -> `marketing.onboarding.d7_due`
- [x] `enqueueProfileIncompleteReminderEmails` -> `profile.incomplete.reminder`
- [x] `enqueueReactivation30DaysEmails` -> `growth.reactivation.30_days`
- [x] `enqueueNearbyNewListingsEmails` -> `growth.nearby_new_listings`
- [x] `sendReferralInviteEmail` -> `growth.referral_invite`

## Couverture effective des 21 nouveaux templates

- [x] Compte et auth: couverts par des Functions emettrices reelles
- [x] Listings: `listing.submitted`, `listing.published`, `listing.rejected` et `listing.first_not_published.reminder` emis reellement
- [x] Messagerie: le template `message_received` est alimente via le mapper par `message.created.new_thread` et `message.created.existing_thread`
- [x] Billing: `billing.payment.succeeded`, `billing.payment.failed`, `billing.subscription.renewed`, `billing.subscription.expired` emis reellement
- [x] Growth: `growth.reactivation.30_days`, `growth.nearby_new_listings`, `growth.referral_invite` emis reellement

## Pipeline email backend confirme

- [x] `enqueueEmailJobsFromEventTrigger`
- [x] `processEmailJobTrigger`
- [x] `processScheduledEmailDigests`
- [x] `retryFailedEmailJobs`
- [x] `cleanupExpiredEmailJobs`
- [x] `handleEmailProviderWebhook`
- [x] Mapping evenement -> template mis a jour dans `functions/src/modules/email/events/mapper.ts`
- [x] Worker/queue relies au registre de compatibilite

## Validation effectuee

- [x] `npm --prefix functions run build`
- [x] `npm --prefix functions test`
- [x] Resultat final tests backend: 62 passes, 0 echec
- [x] Correction appliquee avant validation finale: ajout de `normalizeEmail` et `extractFirstName` dans `functions/src/modules/marketing/scheduled.ts`

## Audit post-deploiement

- [x] Script ajoute: `npm --prefix functions run email:audit:new-events`
- [x] Evenements suivis par defaut:
- [x] `user.otp.requested`
- [x] `profile.verified`
- [x] `user.account.deletion.requested`
- [x] `user.account.deleted`
- [x] `billing.subscription.renewed`
- [x] `billing.subscription.expired`
- [x] `listing.first_not_published.reminder`
- [x] `profile.incomplete.reminder`
- [x] `growth.reactivation.30_days`
- [x] `growth.nearby_new_listings`
- [x] `growth.referral_invite`

Commande recommandee apres deploiement:

```bash
npm --prefix functions run email:audit:new-events -- --project=presto-app-74abe --hours=24
```

## Reste a faire hors code

- [ ] Committer les changements si validation metier ok
- [ ] Deployer les Functions sur le projet cible
- [ ] Executer l'audit post-deploiement sur la fenetre desiree
- [ ] Verifier dans Firestore la chaine `email_events` -> `email_jobs` -> `email_logs` pour les nouveaux flux
