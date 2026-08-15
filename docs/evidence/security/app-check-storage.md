# Preuve — App Check appliqué sur Cloud Storage

Contrôle : `app-check-storage-enforced` (`quality/security-controls.json`).

## Nature de la preuve

Observation de la console Firebase, projet `ilipresto`
(`presto-app-74abe`), page **App Check → APIs**, relevée le 2026-08-14 par le
propriétaire du projet.

| API | État |
|---|---|
| Storage | **Appliqué** |

Aucune métrique de trafic n'était encore affichée au moment du relevé — la
console indique que « les métriques s'afficheront lorsque l'API Storage
recevra des requêtes ». L'état d'enforcement est en revanche explicite.

## Limite de cette preuve

Relevé de console, non reproductible depuis l'intégration continue, donc daté.
À revérifier lors de la revue de sécurité suivante. Il serait utile de
confirmer le taux de requêtes validées une fois que du trafic Storage aura été
observé, afin de s'assurer qu'aucun client légitime n'est rejeté.

## Contexte

Les autres API du projet relevées comme appliquées lors du même contrôle :
Realtime Database, Firebase AI Logic (mode basique), Authentication (99 % de
requêtes validées), Places API (New) et Google Identity for iOS.

Vérifié le 2026-08-14.
