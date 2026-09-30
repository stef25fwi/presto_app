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
