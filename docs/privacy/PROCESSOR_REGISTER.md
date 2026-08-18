# Registre opérationnel des prestataires et SDK — iliprestō

Révision : **2026-08-18**

Ce registre sert de preuve de revue pour la politique de confidentialité et les déclarations Store. Il ne remplace pas le registre RGPD complet ni l’analyse contractuelle/DPA.

| Prestataire / SDK | Rôle dans iliprestō | Données principales | Finalité | Activation / consentement | Point de contrôle release |
|---|---|---|---|---|---|
| Firebase Authentication | authentification | e-mail, téléphone, UID, fournisseur social, IP/métadonnées techniques | compte, sécurité | nécessaire au compte | vérifier providers actifs et templates Auth |
| Cloud Firestore | base applicative | profils, annonces, messages, avis, métadonnées | fonctionnement | nécessaire | règles Firestore + minimisation |
| Firebase Storage | fichiers | photos, audio, documents, pièces jointes | fonctionnement | selon action utilisateur | règles Storage + suppression |
| Cloud Functions for Firebase | backend | données nécessaires aux traitements déclenchés | fonctionnement, sécurité, vérification | selon fonction | logs sans secrets/données excessives |
| Firebase Cloud Messaging | notifications | jeton installation, préférences et métadonnées push | notifications | permission OS lorsque requise | suppression/rotation tokens |
| Firebase Remote Config | configuration | identifiants/métadonnées techniques selon SDK | configuration | nécessaire/technique | pas de données métier dans paramètres |
| Firebase Analytics | mesure audience | interactions, identifiants techniques et propriétés configurées | analytics | **consentement analytics** selon contexte | collecte désactivée tant que refus |
| Firebase Crashlytics | diagnostic | crash logs, stack traces, appareil, version | stabilité | diagnostic technique | vérifier absence de données sensibles dans custom logs |
| Firebase Performance | performance | temps de réponse, traces, appareil/réseau | performance | diagnostic technique | vérifier traces personnalisées |
| Firebase App Check | intégrité | jetons et signaux d’intégrité | sécurité / anti-abus | nécessaire sécurité | vérifier provider et enforcement |
| reCAPTCHA Enterprise | anti-bot | signaux techniques et risque | sécurité | nécessaire au parcours protégé | disclosure + configuration minimale |
| Play Integrity | intégrité Android | signaux d’intégrité appareil/app | sécurité | nécessaire lorsque activé | empreintes / config Play |
| Firebase AI / Google | assistance IA | textes, images, audio ou contenus fournis à la fonction | génération demandée | action volontaire utilisateur | prompts minimisés, pas de secret, disclosure Store |
| Google Mobile Ads / AdMob | publicité tierce | IP, localisation approx., device/ad ID disponible, interactions Ads, diagnostics, performances | publicité/mesure | **marketing + UMP** ; ATT iOS si applicable | `canRequestAds()` obligatoire avant requête |
| Google UMP | gestion consentement Ads | choix réglementaires, état de consentement | conformité Ads | selon zone/configuration | message GDPR publié + privacy options |
| Google Sign-In | fournisseur d’identité | identité/e-mail autorisés, identifiant fournisseur | authentification | choix utilisateur | scopes minimaux |
| Facebook Login via Firebase | fournisseur d’identité | e-mail, profil public/ID autorisés | authentification | choix utilisateur | scopes `email` + `public_profile` uniquement |
| Sign in with Apple | fournisseur d’identité | identifiant Apple, e-mail/nom lorsque transmis | authentification | choix utilisateur | scopes minimaux |
| Prestataire e-mail | transactionnel/support | e-mail, contenu nécessaire au message | notifications/support | selon opération | contrat, rétention, logs |
| Stripe | paiement futur uniquement en mode commercial | références transaction/abonnement ; données bancaires chez Stripe | paiement | **désactivé en bêta gratuite** | nouvelle revue Store/Play Billing avant activation |

## Exigences permanentes

- Ne pas ajouter de SDK réseau sans mise à jour de ce registre et de `STORE_DATA_INVENTORY.md`.
- Vérifier les conditions/DPA et mécanismes de transfert au moment de la mise en production commerciale.
- Les SDK publicitaires restent bloqués avant consentement applicable.
- Les données de vérification téléphone/SIRET ne valent jamais approbation ou garantie d’un prestataire par iliprestō.
- Une montée de version majeure Firebase/Ads déclenche une revue des disclosures Google Play et Apple.
