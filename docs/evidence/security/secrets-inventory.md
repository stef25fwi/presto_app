# Inventaire des secrets — 30 septembre 2026

Auteur du relevé source : Codex. Projet : `presto-app-74abe`.
Dépôt : `stef25fwi/presto_app`, PR #1464.
**Contrôle `secrets-inventory-current` : pending.**

Les références du code sont actualisées. La présence réelle, les propriétaires
et les rotations ne sont pas attestés : aucun accès GCP authentifié ou accès
aux métadonnées des secrets GitHub n'est disponible ici. Une référence de
code n'est pas une preuve d'existence dans la console.

## Secret Manager — références defineSecret

| Nom | Usage | Propriétaire / rotation confirmée |
|---|---|---|
| BREVO_API_KEY | Envoi e-mail | À confirmer |
| BREVO_WEBHOOK_SECRET | Authentification webhook Brevo | À confirmer |
| EMAIL_PROVIDER_API_KEY | Provider Resend | À confirmer |
| EMAIL_PROVIDER_WEBHOOK_SECRET | Signature Resend/Svix | À confirmer |
| GOOGLE_PLACES_API_KEY | Places, manquant de l'ancien inventaire | À confirmer |
| OPENAI_API_KEY | IA | À confirmer |
| STRIPE_PRICE_ILIPRESTO_PLUS | Identifiant de prix | À confirmer ; rotation de secret non applicable |
| STRIPE_PRICE_ILIPRO | Identifiant de prix | À confirmer ; rotation de secret non applicable |
| STRIPE_SECRET_KEY | API Stripe | À confirmer |
| STRIPE_WEBHOOK_SECRET | Signature Stripe | À confirmer |
| VEO_API_KEY | Génération vidéo admin | À confirmer |

## GitHub Actions — références secrets.*

| Références | Nature | Propriétaire / rotation confirmée |
|---|---|---|
| FIREBASE_TOKEN, FIREBASE_STAGING_TOKEN | Jetons CLI persistants | À confirmer |
| KEYSTORE_B64, KEYSTORE_PASSWORD, KEY_PASSWORD | Signature Android | À confirmer |
| KEY_ALIAS | Alias de signature | À confirmer ; identifiant |
| PLAY_SERVICE_ACCOUNT_JSON | Identité Play | À confirmer, présence non déduite des anciennes checklists |
| IOS_DIST_CERT_P12_B64, IOS_DIST_CERT_PASSWORD, IOS_PROVISIONING_PROFILE_B64 | Signature iOS | À confirmer |
| APPSTORE_API_PRIVATE_KEY | Clé privée App Store Connect | À confirmer |
| APPSTORE_API_KEY_ID, APPSTORE_API_ISSUER_ID, IOS_TEAM_ID | Identifiants Apple | À confirmer ; rotation de secret non applicable |
| WIF_PROVIDER, WIF_SERVICE_ACCOUNT | Identifiants de fédération | À confirmer ; pas de jeton durable dans ces identifiants |
| APPCHECK_RECAPTCHA_SITE_KEY, FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_PROJECT_ID, FIREBASE_STAGING_PROJECT_ID | Configuration cliente/publique | À confirmer ; pas des secrets serveur |

`GITHUB_TOKEN` est éphémère et émis par job. Les secrets d'organisation,
s'ils sont ajoutés ultérieurement, doivent aussi être rapprochés de leur
inventaire. Le dépôt appartient actuellement à un compte utilisateur.

## Collecte sans valeurs

```bash
python3 tools/security/collect_external_evidence.py --github
```

Le collecteur utilise uniquement `gcloud secrets list`, `gcloud secrets
versions list` et les endpoints GitHub de liste des secrets du dépôt et de
tous les environnements accessibles. Il n'appelle jamais `versions access`.
Les CLIs nécessitent une identité disposant des droits de lecture metadata.

Compléter pour chaque ressource effectivement présente, même non référencée :
nom, stockage/périmètre, propriétaire, date de rotation confirmée et référence
non sensible de l'opération. `createTime` d'une version ou `updated_at`
GitHub ne prouve pas la révocation de l'ancienne clé chez le fournisseur.
Justifier explicitement « non applicable » pour les identifiants ; ne pas
faire tourner une clé de signature mobile à seule fin de remplir un tableau.

Recherche ciblée sur 2 524 fichiers suivis au 30/09 : aucun secret complet
correspondant aux motifs Stripe, AWS et blocs de clé privée identifié.
Trois candidats contenaient seulement des motifs de détection/caviardage
`BEGIN PRIVATE KEY` dans des outils de contrôle. Cette recherche ne couvre
ni tout l'historique Git, ni les consoles, ni les journaux externes.

La collecte locale a échoué comme attendu : gcloud indisponible et GitHub
non collecté. La date de ce document ne remplace pas les rotations manquantes.

Références :
- https://cloud.google.com/sdk/gcloud/reference/secrets/versions/list
- https://docs.github.com/en/rest/actions/secrets

## Inventaire réel reçu de Cloud Shell — 30/09/2026

Source : export opérateur du `2026-09-30T12:58:54.552838+00:00` ; collecte
sans erreur, projet numérique `151421230024`. Quinze ressources Secret
Manager et dix-sept secrets/configurations GitHub recensés. Les onze
références defineSecret du code sont présentes. Quatre ressources GCP
supplémentaires sont désormais incluses. Aucun ownerLabel renseigné ; les
champs lastRotationConfirmed restent non attestés. Ce champ est laissé à
null par conception du collecteur : il ne prouve pas que le fournisseur n'a
jamais effectué de rotation.

| Ressource GCP | Dernière version créée (UTC) | Versions ENABLED observées |
|---|---|---:|
| BREVO_API_KEY | v10 — 2026-08-26 | 10 |
| BREVO_WEBHOOK_SECRET | v8 — 2026-04-16 | 8 |
| EMAIL_PROVIDER_API_KEY | v1 — 2026-03-22 | 1 |
| EMAIL_PROVIDER_WEBHOOK_SECRET | v1 — 2026-03-22 | 1 |
| GOOGLE_PLACES_API_KEY | v1 — 2026-01-02 | 1 |
| OPENAI_API_KEY | v8 — 2026-07-01 | 8 |
| RECAPTCHA_ENTERPRISE_SITE_KEY | v2 — 2026-05-09 | 2 |
| STRIPE_PRICE_ILIPRESTO_PLUS | v1 — 2026-07-10 | 1 |
| STRIPE_PRICE_ILIPRO | v1 — 2026-07-10 | 1 |
| STRIPE_SECRET_KEY | v2 — 2026-08-01 | 2 |
| STRIPE_WEBHOOK_SECRET | v3 — 2026-07-10 | 3 |
| VEO_API_KEY | v1 — 2026-07-29 | 1 |
| Connexion App Hosting avqfysf | v1 — 2025-12-21 | 1 |
| Connexion App Hosting m81pshh | v1 — 2026-04-15 | 1 |
| Extension firestore-stripe-payments-STRIPE_API_KEY | v1 — 2026-04-08 | 1 |

Les dates sont des créations de versions, pas des rotations de credential.
La matrice impose un inventaire daté de moins de 90 jours ; elle n'impose pas
une rotation universelle tous les 90 jours. Plusieurs versions ENABLED ne
prouvent pas qu'elles sont utilisées, ni que leurs valeurs sont différentes.
Avant de les désactiver, relever les versions liées aux Functions/Cloud Run,
aux connexions App Hosting et à l'extension Stripe. Ne rien détruire sur la
seule base de cet export. Les OAuth App Hosting sont potentiellement gérés
par le service : documenter le gestionnaire et la politique applicable.

| Stockage GitHub | Ressource effectivement présente | updated_at UTC |
|---|---|---|
| Dépôt | FIREBASE_API_KEY | 2026-07-18 |
| Dépôt | FIREBASE_APP_ID | 2026-07-18 |
| Dépôt | FIREBASE_MESSAGING_SENDER_ID | 2026-07-18 |
| Dépôt | FIREBASE_SERVICE_ACCOUNT_PRESTO_APP_74ABE | 2026-07-18 |
| recaptcha | APPCHECK_RECAPTCHA_SITE_KEY | 2026-05-10 |
| recaptcha | FCM_WEB_VAPID_KEY | 2026-06-19 |
| recaptcha | GOOGLE_CREDENTIALS_B64 | 2026-05-10 |
| recaptcha | KEYSTORE_B64 | 2026-06-26 |
| recaptcha | KEYSTORE_PASSWORD | 2026-06-26 |
| recaptcha | KEY_ALIAS | 2026-06-26 |
| recaptcha | KEY_PASSWORD | 2026-06-26 |
| recaptcha | MARKETPLACE_RECAPTCHA_WEB_SITE_KEY | 2026-05-18 |
| recaptcha | WIF_PROVIDER | 2026-07-20 |
| recaptcha | WIF_SERVICE_ACCOUNT | 2026-07-20 |
| staging | FIREBASE_STAGING_PROJECT_ID | 2026-07-15 |
| staging | FIREBASE_STAGING_TOKEN | 2026-07-15 |
| staging | STAGING_APPCHECK_RECAPTCHA_SITE_KEY | 2026-07-15 |

Le relevé ne contient pas les secrets de signature iOS/App Store ni
PLAY_SERVICE_ACCOUNT_JSON ; les workflows les référencent, sans prouver
leur existence. Les identités persistantes FIREBASE_SERVICE_ACCOUNT et
GOOGLE_CREDENTIALS_B64 doivent être rapprochées de WIF et de leurs usages
réels, sans lire leurs valeurs dans un rapport public.

**Décision : pending.** L'inventaire réel est disponible ; il reste à
attribuer les ressources et confirmer les dates de rotation ou justifier
non-applicabilité/service-managed pour chacune. La preuve peut être
complétée par une attestation opérateur nominative sans communiquer aucune
valeur de secret. Aucun statut vérifié ni rotation n'est inventé.
