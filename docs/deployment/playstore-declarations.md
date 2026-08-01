# Déclarations Play Console — brouillon à valider

Réponses préparées à partir de l'inventaire du code au 1er août 2026
(commit `e5ddc88`). **Ce document n'est pas une déclaration valide en soi** :
il sert de base à la saisie dans Play Console, qui reste un acte de
l'éditeur. Toute réponse marquée « à confirmer » exige une décision humaine.

Références : `docs/deployment/playstore-launch-checklist.md` (sections 4 et 5).

---

## 1. Sécurité des données (*Data safety*)

### Cadre général

| Question | Réponse | Fondement dans le code |
|---|---|---|
| Les données sont-elles chiffrées en transit ? | **Oui** | Firebase (HTTPS/TLS) pour tous les appels ; HSTS sur le domaine (`firebase.json`) |
| L'utilisateur peut-il demander la suppression de ses données ? | **Oui** | `lib/pages/account/delete_account_page.dart` + page publique `/suppression-compte` |
| Les données sont-elles partagées avec des tiers ? | **Oui** (Google : Firebase, AdMob) | dépendances `firebase_*`, `google_mobile_ads` |
| Application destinée aux enfants ? | **Non** — à confirmer avec le public cible retenu | messagerie ouverte entre adultes |

### Types de données à déclarer

| Catégorie | Type | Collecté | Partagé | Finalité | Obligatoire | Source |
|---|---|---|---|---|---|---|
| Informations personnelles | Nom / pseudo | Oui | Non | Fonctionnalité, compte | Oui | `displayName` (`user_profile_save_payload.dart`) |
| Informations personnelles | Adresse e-mail | Oui | Non | Fonctionnalité, compte | Oui | `firebase_auth` |
| Informations personnelles | Numéro de téléphone | Oui | Non | Mise en relation | Non | `phone` (`user_profile_save_payload.dart`) |
| Localisation | Localisation approximative | Oui | Non | Fonctionnalité | Non | **ville et code postal saisis par l'utilisateur**, aucun capteur : aucun plugin de géolocalisation dans `pubspec.yaml` |
| Messages | Messages dans l'application | Oui | Non | Fonctionnalité | Oui | messagerie Firestore |
| Photos et vidéos | Photos | Oui | Non | Fonctionnalité (annonces, avatar) | Non | `image_picker`, `firebase_storage` |
| Fichiers audio | Enregistrements vocaux | Oui | Non | Fonctionnalité | Non | `record`, `just_audio` |
| Fichiers et documents | Documents | Oui | Non | Fonctionnalité | Non | `file_picker`, export `pdf` |
| Identifiants | Identifiant utilisateur | Oui | Oui | Analytics, publicité | Oui | Firebase UID, Analytics |
| Identifiants | **Identifiant publicitaire** | Oui | Oui | Publicité | Non | `google_mobile_ads` fusionne la permission `com.google.android.gms.permission.AD_ID` |
| Activité dans l'app | Interactions | Oui | Oui | Analytics | Non | `firebase_analytics` |
| Activité dans l'app | Recherches | Oui | Non | Fonctionnalité, analytics | Non | recherche d'annonces |
| Performances | Plantages | Oui | Oui | Diagnostic | Non | `firebase_crashlytics` |
| Performances | Diagnostics | Oui | Oui | Diagnostic | Non | `firebase_performance` |

> **Point de vigilance.** Déclarer « localisation approximative » comme
> *saisie par l'utilisateur* et non comme *collectée par l'appareil* : la
> déclaration inverse déclencherait une demande de justification que le code
> ne peut pas appuyer.

> **Contenus soumis à l'IA.** `firebase_ai` transmet à Google des textes et
> images fournis par l'utilisateur pour l'assistance à la publication. À
> refléter dans la politique de confidentialité et dans la section
> « partage » si le traitement n'est pas strictement éphémère — **à
> confirmer** avec la configuration Firebase AI retenue.

## 2. Permissions sensibles

| Permission | Déclarée dans | Usage réel | À fournir |
|---|---|---|---|
| `RECORD_AUDIO` | `AndroidManifest.xml` | messages vocaux (`record`) | Divulgation proéminente avant la première demande + explication dans la fiche |
| `CAMERA` | `AndroidManifest.xml` | photos d'annonce et avatar (`image_picker`) | Idem |
| `POST_NOTIFICATIONS` | `AndroidManifest.xml` | notifications de messages | Demandé au runtime (`lib/services/notification_service.dart:297`) — conforme |
| `INTERNET`, `WAKE_LOCK` | `AndroidManifest.xml` | réseau et réception push | Aucune déclaration requise |
| `AD_ID` (fusionnée) | `google_mobile_ads` | publicité | **Doit apparaître dans Sécurité des données** (cf. tableau ci-dessus) |

Aucune permission de localisation, de contacts, de SMS ni de stockage
externe étendu n'est demandée — à conserver tel quel, ce sont les
déclarations les plus coûteuses à justifier.

## 3. Classification du contenu (questionnaire IARC)

Éléments à déclarer, tirés du fonctionnement réel :

- **Interaction entre utilisateurs : oui.** Messagerie directe entre
  utilisateurs (`lib/pages/messages/`).
- **Partage de contenu généré par les utilisateurs : oui.** Annonces, photos,
  messages vocaux.
- **Partage de localisation entre utilisateurs : oui, approximative.** La
  ville et le code postal d'une annonce sont visibles publiquement.
- **Achats intégrés : non** en mode *free beta* — voir la réserve Play Billing
  ci-dessous.
- **Violence, contenu sexuel, jeux d'argent, substances : non.**
- **Publicité : oui**, bannières AdMob.

Dispositifs de modération à signaler dans le questionnaire (tous présents) :
signalement d'annonce (`lib/pages/offers/offer_details_page.dart`),
signalement de conversation et blocage d'utilisateur
(`lib/pages/messages/conversation_thread_page.dart`), console de modération
admin (`lib/admin/messaging/`).

## 4. Contenu de l'application

| Section Play Console | Valeur | État |
|---|---|---|
| Politique de confidentialité | `https://ilipresto.fr/confidentialite` | route publique en place |
| Conditions d'utilisation | `https://ilipresto.fr/cgu` | route publique en place |
| Mentions légales | `https://ilipresto.fr/mentions-legales` | route publique en place |
| Suppression du compte | `https://ilipresto.fr/suppression-compte` | route publique en place |
| Contient des annonces | **Oui** | à cocher |
| Accès à l'application | compte de démonstration à fournir | **à créer** |
| Application financière | Non | à confirmer |
| Application de santé | Non | à confirmer |

> **Compte de démonstration.** L'application est intégralement derrière
> authentification. Sans identifiants de test dans *Accès à l'application*, le
> reviewer ne voit rien et le rejet est quasi systématique. Prévoir un compte
> dédié, avec des annonces et une conversation déjà peuplées, et le mentionner
> dans les instructions.

## 5. Réserve Play Billing

Le checkout Stripe est neutralisé hors mode commercial
(`lib/features/subscriptions/subscription_action_placeholders.dart:78`), donc
la déclaration « pas d'achats intégrés » est exacte **aujourd'hui**.

Le jour où le mode commercial est activé, un abonnement souscrit depuis
l'application Android via Stripe enfreint la règle Play Billing dès lors
qu'il ouvre des fonctionnalités numériques. Deux issues : passer par Play
Billing, ou réserver le parcours d'abonnement au web en le gardant derrière
`kIsWeb`. À trancher **avant** le basculement, pas après.

## 6. Test fermé préalable

Un compte développeur personnel créé après novembre 2023 doit réunir
**12 testeurs pendant 14 jours continus** en test fermé avant de pouvoir
demander l'accès à la production. C'est le délai le plus long de toute la
préparation : à lancer dès que la piste interne est saine, sans attendre que
le reste de la checklist soit fini.
