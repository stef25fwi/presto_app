# Preuve — inventaire des secrets à jour

**Contrôle** : `secrets-inventory-current`
**Nature** : `automated` — l'inventaire est comparé au code à chaque exécution.

## Commande de vérification

```bash
node tools/quality/check_secrets_inventory.mjs
```

Le contrôle échoue si :

- un `defineSecret("X")` apparaît dans `functions/src` sans entrée dans
  `quality/secrets-inventory.json` (`secret-non-inventorie`) ;
- une entrée d'inventaire ne correspond plus à aucun secret du code
  (`entree-orpheline`) ;
- une entrée est dupliquée ou n'expose pas son propriétaire et son usage
  (`doublon-inventaire`, `champ-manquant`).

Un inventaire rédigé à la main dérive dès le premier ajout de secret. C'est
précisément ce que ce contrôle empêche.

## État mesuré au 2026-07-29 (commit `252f190`)

10 secrets déclarés dans le code, 10 inventoriés, 0 écart.

L'inventaire versionné est `quality/secrets-inventory.json`. Il ne contient
**aucune valeur** : uniquement des identifiants, un propriétaire, un usage et
une périodicité de rotation.

| Secret | Domaine | Rotation |
|---|---|---:|
| `OPENAI_API_KEY` | ai | 180 j |
| `EMAIL_PROVIDER_API_KEY` | platform | 365 j |
| `EMAIL_PROVIDER_WEBHOOK_SECRET` | platform | 365 j |
| `BREVO_API_KEY` | platform | 365 j |
| `BREVO_WEBHOOK_SECRET` | platform | 365 j |
| `STRIPE_SECRET_KEY` | billing | 180 j |
| `STRIPE_WEBHOOK_SECRET` | billing | 180 j |
| `STRIPE_PRICE_ILIPRESTO_PLUS` | billing | — (identifiant de tarif) |
| `STRIPE_PRICE_ILIPRO` | billing | — (identifiant de tarif) |
| `VEO_API_KEY` | ai | 180 j (non provisionné) |

## Stockage

Tous les secrets passent par Google Secret Manager via
`firebase-functions/params` `defineSecret()`, et sont injectés dans les
Functions par la clause `secrets: [...]` de chaque déclaration. Aucune valeur
n'est présente dans le dépôt — vérifié par recherche de motifs
(`sk_live_`, `sk_test_`, `-----BEGIN PRIVATE KEY-----`, `AKIA…`) : aucun
résultat dans le code source.

`VEO_API_KEY` est délibérément déclaré dans `videomaker.ts` plutôt que dans
`config/env.ts` : `defineSecret()` enregistre le secret dès le chargement du
module, et `env.ts` est importé par `index.ts` à chaque déploiement. Le
déclarer globalement ferait demander sa création de façon interactive à
`firebase deploy`, ce qui bloque une CI non interactive tant que le secret
n'existe pas dans Secret Manager.

## Limites

Ce contrôle prouve que l'inventaire décrit exactement les secrets utilisés par
le code. Il ne prouve pas que la rotation annoncée a effectivement eu lieu :
les dates de dernière rotation vivent dans Secret Manager et relèvent d'une
attestation d'opérateur.
