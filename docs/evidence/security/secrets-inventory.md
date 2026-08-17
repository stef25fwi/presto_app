# Inventaire des secrets de production — amorcé le 16/08/2026

Contrôle : `secrets-inventory-current` (`quality/security-controls.json`).

## Statut : amorcé, pas complet

Le contrôle exige, pour chaque secret : nom, stockage, **propriétaire** et
**date de dernière rotation**. Les deux premières colonnes sont vérifiables
depuis le code — c'est ce que fait ce document, par recherche exhaustive des
références à des secrets dans le dépôt. Les deux dernières (propriétaire,
rotation) sont des faits organisationnels qui n'existent dans aucun fichier
du dépôt : aucune session de code ne peut les produire sans les inventer.

**Ce document réduit le travail restant à une revue de complétion — cocher
propriétaire et date pour chaque ligne — plutôt qu'à un inventaire à
construire depuis zéro.**

## Secrets Cloud Functions (Google Secret Manager, via `defineSecret`)

Recherche : `grep -rn "defineSecret(" functions/src`.

| Secret | Utilisé par | Propriétaire | Dernière rotation |
|---|---|---|---|
| `STRIPE_SECRET_KEY` | Appels API Stripe (`billing/callables.ts`) | À renseigner | À renseigner |
| `STRIPE_WEBHOOK_SECRET` | Vérification de signature webhook (`stripe_webhook.ts`) | À renseigner | À renseigner |
| `STRIPE_PRICE_ILIPRESTO_PLUS` | Identifiant de prix Stripe (pas un secret au sens strict, mais géré via Secret Manager) | À renseigner | À renseigner |
| `STRIPE_PRICE_ILIPRO` | Identifiant de prix Stripe (idem) | À renseigner | À renseigner |
| `OPENAI_API_KEY` | Transcription/génération micro-IA | À renseigner | À renseigner |
| `VEO_API_KEY` | Génération vidéo admin | À renseigner | À renseigner |
| `BREVO_API_KEY` | Provider email principal | À renseigner | À renseigner |
| `BREVO_WEBHOOK_SECRET` | Authentification des webhooks Brevo entrants (`handler.ts`) | À renseigner | À renseigner |
| `EMAIL_PROVIDER_API_KEY` | Provider email de repli (Resend) | À renseigner | À renseigner |
| `EMAIL_PROVIDER_WEBHOOK_SECRET` | Authentification webhooks du provider de repli | À renseigner | À renseigner |

## Secrets GitHub Actions (`secrets.*` référencés dans `.github/workflows/`)

Recherche : `grep -rhoE "secrets\.[A-Z_0-9]+" .github/workflows/*.yml`.

| Secret | Rôle apparent | Propriétaire | Dernière rotation |
|---|---|---|---|
| `FIREBASE_TOKEN` | Authentification CLI Firebase (déploiement) | À renseigner | À renseigner |
| `FIREBASE_API_KEY` | Configuration client Firebase en CI | À renseigner | À renseigner |
| `FIREBASE_APP_ID` | Configuration client Firebase en CI | À renseigner | À renseigner |
| `FIREBASE_PROJECT_ID` | Identifiant projet production | À renseigner | À renseigner |
| `FIREBASE_STAGING_PROJECT_ID` | Identifiant projet staging | À renseigner | À renseigner |
| `FIREBASE_STAGING_TOKEN` | Authentification CLI Firebase (staging) | À renseigner | À renseigner |
| `WIF_PROVIDER` | Workload Identity Federation (auth GCP sans clé statique) | À renseigner | N/A — fédéré, pas de rotation manuelle |
| `WIF_SERVICE_ACCOUNT` | Compte de service ciblé par la fédération | À renseigner | À renseigner |
| `APPCHECK_RECAPTCHA_SITE_KEY` | Clé publique reCAPTCHA Enterprise (App Check web) | À renseigner | À renseigner |
| `KEYSTORE_B64` | Keystore de signature Android (base64) | À renseigner | À renseigner |
| `KEYSTORE_PASSWORD` | Mot de passe du keystore Android | À renseigner | À renseigner |
| `KEY_ALIAS` | Alias de la clé de signature Android | À renseigner | À renseigner |
| `KEY_PASSWORD` | Mot de passe de la clé de signature Android | À renseigner | À renseigner |
| `PLAY_SERVICE_ACCOUNT_JSON` | Compte de service pour l'upload Play Console | À renseigner | **Non applicable — le secret n'existe pas encore**, d'après `docs/deployment/playstore-launch-checklist.md` |
| `IOS_DIST_CERT_P12_B64` | Certificat de distribution iOS (base64) | À renseigner | À renseigner |
| `IOS_DIST_CERT_PASSWORD` | Mot de passe du certificat iOS | À renseigner | À renseigner |
| `IOS_PROVISIONING_PROFILE_B64` | Profil de provisionnement iOS (base64) | À renseigner | À renseigner |
| `IOS_TEAM_ID` | Identifiant d'équipe Apple Developer | À renseigner | N/A — identifiant, pas un secret rotatif |
| `APPSTORE_API_KEY_ID` | Clé API App Store Connect | À renseigner | À renseigner |
| `APPSTORE_API_ISSUER_ID` | Émetteur de la clé API App Store Connect | À renseigner | N/A — identifiant, pas un secret rotatif |
| `APPSTORE_API_PRIVATE_KEY` | Clé privée API App Store Connect | À renseigner | À renseigner |
| `GITHUB_TOKEN` | Jeton natif GitHub Actions | GitHub (auto-généré, auto-rotation par run) | Automatique — hors périmètre |

## Ce qui n'a volontairement pas été inclus

- Les variables `NEXT_PUBLIC_*`/configuration Firebase côté client
  (`firebase_options.dart`) : publiques par construction (clé API Firebase
  web), protégées par les restrictions d'API et App Check, pas par le secret
  lui-même. Suivies séparément par le contrôle `api-keys-restricted`.
- Les préfixes `sk_live_`/`sk_test_` trouvés dans `stripe_mode.ts` : ce sont
  des motifs de validation de format, pas des clés — déjà écarté dans
  `docs/evidence/security/dependency-audit.md` et l'audit général du 15/08.

## Prochaine étape

Compléter les colonnes « Propriétaire » et « Dernière rotation » depuis la
console GitHub (Settings → Secrets) et Google Secret Manager, qui seules
portent ces informations. Le contrôle ne peut passer `verified` qu'une fois
ce tableau intégralement renseigné et daté de moins de 90 jours, comme
l'exige `quality/security-controls.json`.

Amorcé le 2026-08-16.
