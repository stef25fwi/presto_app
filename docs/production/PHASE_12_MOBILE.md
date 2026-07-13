# Phase 12 — Préparation mobile

## Objectif

Rendre mesurable la préparation des versions Android et iOS avant distribution sur les stores.

## Contrôles suivis

- builds Android et iOS reproductibles ;
- permissions minimales et documentées ;
- notifications FCM/APNs validées sur appareils réels ;
- deep links et universal links ;
- Crashlytics mobile ;
- métadonnées Google Play et App Store ;
- signature des releases et gestion des secrets.

Le registre `quality/mobile_readiness.json` distingue les preuves déjà présentes des validations qui nécessitent encore un build signé, un appareil réel ou un accès store.

## Commandes

```bash
node tools/quality/check_mobile_readiness.test.mjs
node tools/quality/check_mobile_readiness.mjs
```

Le mode strict est destiné à la clôture finale de la phase :

```bash
node tools/quality/check_mobile_readiness.mjs --enforce
```

Le workflow conserve le rapport JSON pendant 30 jours afin de fournir une preuve auditable.
