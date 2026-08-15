# Preuve — App Check appliqué sur Cloud Firestore

Contrôle : `app-check-firestore-enforced` (`quality/security-controls.json`).

## Nature de la preuve

Observation de la console Firebase, projet `ilipresto`
(`presto-app-74abe`), page **App Check → APIs**, relevée le 2026-08-14 par le
propriétaire du projet.

| API | Requêtes validées | Non validées | État |
|---|---:|---:|---|
| Cloud Firestore | **100 %** | 0 % | **Appliqué** |

Le taux de 100 % de requêtes validées confirme que l'enforcement est non
seulement activé, mais qu'aucun trafic légitime n'est rejeté — l'application
en production attache bien ses jetons.

## Limite de cette preuve

Il s'agit d'un relevé de console, non reproductible depuis l'intégration
continue : l'état d'enforcement d'une API Firebase n'est pas exposé au dépôt.
Sa validité est donc datée. À revérifier lors de la revue de sécurité
suivante, ou après toute modification de la configuration App Check.

## Remarque associée

`firestore.rules` documente que `hasAppCheck()` est volontairement omis sur
l'écriture de `users/{userId}`, le SDK Flutter Web n'attachant pas de jeton
App Check aux requêtes Firestore. Ce point est compensé par le contrôle de
propriétaire et les champs protégés, et reste à réévaluer si App Check Web
devient disponible pour Firestore.

Vérifié le 2026-08-14.
