# Déploiement progressif du pipeline IA iliprestō

## Objectif

Déployer le pipeline `ilipresto-ai-pipeline-v3` sans interrompre la publication vocale existante. Le callable historique `microIaProcessAudio` reste disponible comme mécanisme de rollback. Le nouveau callable est `microIaProcessAudioV2`.

## Remote Config

| Clé | Type | Valeur sûre initiale | Rôle |
|---|---|---:|---|
| `micro_ia_v2_enabled` | booléen | `false` | Autorise le client à sélectionner V2. |
| `micro_ia_v2_rollout_percent` | entier 0–100 | `0` | Pourcentage stable d'utilisateurs sélectionnés. |
| `micro_ia_v1_fallback_enabled` | booléen | `true` | Replie automatiquement vers V1 après une erreur V2 éligible. |

La sélection est déterministe par UID : un utilisateur reste dans le même groupe pendant toute la montée en charge.

## Séquence recommandée

1. Déployer les Functions avec `micro_ia_v2_enabled=false`.
2. Vérifier que `microIaProcessAudioV2`, `purgeExpiredAiAudio`, `purgeExpiredAiOperationalData` et `adminGetAiMetrics` sont présents.
3. Exécuter le jeu d'évaluation :

   ```bash
   cd functions
   OPENAI_API_KEY=... npm run ai:eval:listing
   ```

4. Faire des essais réels sur des audios WAV, WEBM, M4A et MP4.
5. Activer V2 à 1 %, puis 5 %, 20 %, 50 % et 100 %.
6. Conserver au moins une période d'observation entre chaque palier.
7. Comparer V1 et V2 avec `npm run ai:metrics:report -- 14`.

## Seuils d'arrêt

Revenir immédiatement au palier précédent si l'un de ces critères est atteint :

- taux de réussite V2 inférieur de plus de 3 points à V1 ;
- latence moyenne V2 supérieure de plus de 20 % ;
- taux de fallback supérieur à 25 % ;
- augmentation inexpliquée du coût estimé par traitement ;
- hausse des erreurs `AI_OUTPUT_INVALID`, `AUDIO_TRANSCRIPT_EMPTY` ou `AI_PIPELINE_FAILED` ;
- problème d'authentification ou App Check.

## Rollback sans redéploiement

Dans Firebase Remote Config :

```text
micro_ia_v2_enabled = false
micro_ia_v2_rollout_percent = 0
micro_ia_v1_fallback_enabled = true
```

Le client reprend alors le callable historique. La configuration est récupérée toutes les quinze minutes au maximum ; redémarrer l'application accélère la récupération.

## Rétention audio

Les fichiers Storage utilisés par V2 ne sont plus supprimés immédiatement. Ils sont inscrits dans `_ai_audio_cleanup` puis supprimés par `purgeExpiredAiAudio` :

- traitement réussi : rétention approximative de 30 minutes ;
- traitement échoué : rétention approximative de 2 heures ;
- suppression planifiée toutes les quinze minutes.

Cette durée permet les retries et diagnostics sans conserver durablement l'audio.

## Données opérationnelles et RGPD

Les collections suivantes possèdent un champ `expiresAt` et sont également purgées quotidiennement par `purgeExpiredAiOperationalData` :

- `_ai_idempotency` ;
- `_rate_limits` ;
- `_ai_metrics_daily` ;
- `_ai_audio_cleanup`.

La fonction planifiée constitue un filet de sécurité même si une politique TTL Firestore n'est pas activée. Il reste recommandé d'activer le TTL natif sur `expiresAt` pour ces collections.

## Mesure des coûts

Les métriques ne stockent ni texte utilisateur, ni transcription, ni email. Elles agrègent quotidiennement :

- nombre d'opérations ;
- succès et échecs ;
- latence cumulée ;
- fallbacks ;
- résultats servis depuis le cache ;
- tokens d'entrée, de sortie et tokens en cache ;
- durée audio ;
- coût estimé lorsque les variables tarifaires sont renseignées.

Variables facultatives :

```text
OPENAI_INPUT_EUR_PER_MILLION_TOKENS
OPENAI_CACHED_INPUT_EUR_PER_MILLION_TOKENS
OPENAI_OUTPUT_EUR_PER_MILLION_TOKENS
OPENAI_TRANSCRIPTION_EUR_PER_MINUTE
```

## Modèles et rollback modèle

Les modèles sont configurables sans modifier le code Functions :

```text
OPENAI_LISTING_MODEL=gpt-4o-mini-2024-07-18
OPENAI_TRANSCRIBE_MODEL=gpt-4o-mini-transcribe-2025-12-15
OPENAI_VISION_MODEL=gpt-4o-mini-2024-07-18
OPENAI_TTS_MODEL=tts-1
OPENAI_TTS_VOICE=nova
```

Tout changement de modèle doit être validé avec le même jeu d'évaluation avant promotion.

## Contrôle après déploiement

```bash
cd functions
npm run build
npm test
npm run ai:metrics:report -- 7
```

Vérifier également les logs structurés :

- `openai.operation.success` ;
- `openai.operation.failure` ;
- `micro_ia.google_fallback` ;
- `ai.audio_cleanup.completed` ;
- `ai.operational_cleanup.completed`.
