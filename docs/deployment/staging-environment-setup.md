# Mise en place de l'environnement Firebase de staging

Ce document détaille la procédure pour provisionner l'environnement « Staging
cible » décrit dans [`environments.md`](environments.md). Il ne peut pas être
exécuté automatiquement : chaque étape nécessite un accès humain authentifié
à la console Firebase/GCP, Stripe et App Store/Play Console. Ce guide donne
la séquence exacte à suivre.

## Pourquoi c'est nécessaire avant la première publication mobile

`docs/deployment/mobile-release.md` documente des workflows manuels
(`release_android.yml`, `release_ios.yml`) qui pointent aujourd'hui sur le
seul projet Firebase existant, `presto-app-74abe` (production réelle). Sans
projet de staging, le premier build de test (piste interne Play, premier
TestFlight) écrira dans les données réelles : comptes, annonces, messages,
paiements Stripe. Ce document permet d'éviter ça.

## 1. Créer le projet Firebase

1. Console Firebase → *Ajouter un projet* → nom `presto-app-staging` (ou
   équivalent), même organisation GCP que `presto-app-74abe`.
2. Lier une facturation (plan Blaze) : Functions v2, Storage et Firestore en
   ont besoin même à faible usage.
3. Activer les produits utilisés en production : Authentication (Email,
   Google, Apple, Phone), Cloud Firestore, Cloud Storage, Cloud Functions,
   App Check, Cloud Messaging (FCM), Remote Config le cas échéant.

## 2. Enregistrer les apps client

Pour chaque plateforme (Web, Android, iOS) :

```bash
flutterfire configure --project=presto-app-staging --out=lib/firebase_options_staging.dart
```

Ne pas écraser `lib/firebase_options.dart` (production). Le fichier staging
doit être sélectionné par un flavor/target de build distinct (ex. `--dart-define=ENV=staging`
ou un flavor Flutter `staging`), jamais par défaut.

- Android : `flutterfire configure` régénère un `google-services.json` de
  staging — le stocker sous un dossier de flavor séparé, ne pas remplacer
  celui de production dans `android/app/`.
- iOS : même logique avec `GoogleService-Info.plist`, schéma Xcode dédié si
  possible.

## 3. Déployer les règles et index

Depuis une session authentifiée (`firebase login`) avec le projet staging
sélectionné :

```bash
firebase use presto-app-staging
firebase deploy --only firestore:rules,firestore:indexes,storage
npm --prefix functions run build
firebase deploy --only functions
```

Les règles (`firestore.rules`, `storage.rules`) et index
(`firestore.indexes.json`) sont déjà versionnés dans ce dépôt : le staging
doit recevoir exactement les mêmes fichiers que la production, jamais une
version allégée, pour que les tests d'intégration soient représentatifs.

## 4. Secrets et clés externes

Les valeurs doivent être **distinctes** de la production (jamais partagées) :

| Service | Action |
|---|---|
| Stripe | Créer les produits/prix en mode test, utiliser les clés `sk_test_`/`pk_test_`, configurer un endpoint webhook séparé pointant vers les Functions du projet staging. |
| App Check / reCAPTCHA | Nouvelle clé de site reCAPTCHA v2 associée au domaine Hosting du projet staging. |
| OpenAI / Speech-to-Text | Réutilisable avec un plafond mensuel bas dédié (variable d'env séparée), pour ne pas consommer le budget de production défini dans le mode coût minimum. |
| Géoplateforme / adresses | Clé partageable si le quota le permet, sinon clé staging séparée. |
| Firebase Phone Auth (OTP) | Activer le provider Phone + reCAPTCHA v2 web sur le projet staging pour pouvoir enfin tester `confirmPhoneVerified` avec un vrai SMS sans risquer un compte réel. |

## 5. GitHub Actions

1. Créer un environnement GitHub `staging` (Settings → Environments),
   distinct de `recaptcha` (production actuelle — voir la note de
   renommage prévue dans `environments.md`).
2. Provisionner une Workload Identity Federation dédiée au projet staging
   (ne jamais réutiliser le `WIF_PROVIDER`/`WIF_SERVICE_ACCOUNT` de
   production) et l'ajouter comme secrets de l'environnement `staging`.
3. Ajouter un workflow (ou un paramètre d'entrée sur les workflows
   existants) qui déploie Hosting/Functions/Rules sur `presto-app-staging`
   depuis une branche ou un tag dédié, sans toucher au workflow de
   production actuel.
4. Pour `release_android.yml`/`release_ios.yml` : ajouter un input
   `target_environment` (`staging` / `production`), par défaut `staging`,
   pour que le tout premier build signé (AAB/IPA) soit vérifié contre le
   projet staging avant tout envoi réel à Play Console/TestFlight.

## 6. Jeu de données de test

Ne jamais copier des données réelles vers staging. Utiliser
`functions/scripts/seed_marketplace_bootstrap.mjs` (déjà présent dans le
dépôt, mode `--dry-run` disponible) pour peupler le projet staging avec des
comptes et annonces synthétiques après le déploiement des règles.

## 7. Critère de sortie

Le staging est considéré prêt quand :

- [ ] Connexion Email/Google/Apple/Phone fonctionne sur le build staging ;
- [ ] Publication, consultation, messagerie et paiement Stripe test passent
      sans toucher au projet `presto-app-74abe` ;
- [ ] Le premier build mobile signé a été vérifié sur staging avant tout
      déclenchement avec `target_environment: production` ;
- [ ] Les secrets staging et production ne se recoupent sur aucune valeur.

Tant que ces cases ne sont pas cochées, `docs/deployment/release-checklist.md`
ne doit pas être considéré comme satisfait pour une première publication
mobile.
