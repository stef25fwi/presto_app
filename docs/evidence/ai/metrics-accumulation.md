# Accumulation des métriques IA de production — point 8

## Pourquoi une preuve distincte du smoke test

Le smoke test de production prouve qu'un cycle fonctionne le jour où il est
exécuté. Il ne prouve pas que la qualité tient dans la durée. Le point 8
demande explicitement d'accumuler des métriques de production : cette preuve
mesure donc la **profondeur d'observation**, pas seulement l'état instantané.

## Mécanisme

- source : collection Firestore `_ai_metrics_daily`, alimentée par
  `recordAiMetric` (aucun contenu utilisateur, uniquement des compteurs) ;
- calcul : `functions/scripts/ai_metrics_trend.mjs` ;
- exécution : `.github/workflows/ai-metrics-accumulation.yml`, tous les jours
  à 06:00 UTC, artefact conservé 90 jours ;
- exécution complémentaire : le workflow `AI production smoke` produit aussi
  `metrics-trend.json` au même SHA que le smoke test.

```bash
npm --prefix functions run ai:metrics:trend -- --days 30
npm --prefix functions run ai:metrics:trend -- --days 30 --enforce
node tools/quality/check_ai_metrics_trend.test.mjs
```

## Contenu du rapport

| Champ | Rôle |
|---|---|
| `observedDays` / `missingDays` | Profondeur réelle d'observation et trous de collecte |
| `accumulationComplete` | Vrai lorsque `observedDays >= AI_TREND_MIN_OBSERVED_DAYS` |
| `windows.d7` / `d14` / `d30` | Fenêtres glissantes : succès, fallback, cache, latences, coût |
| `byOperation` | Ventilation par opération pour le diagnostic |
| `daily` | Série journalière, base des graphiques et du plafond de coût |
| `gateFailures` | Manquements constatés, vides lorsque la tendance est conforme |

Les latences proviennent des histogrammes de production
(`latencyPercentiles`), pas d'une moyenne : un P95 reste donc interprétable
même quand le volume est faible.

## Seuils appliqués

| Variable | Défaut | Signification |
|---|---:|---|
| `AI_TREND_MIN_OBSERVED_DAYS` | 14 | Jours réellement mesurés exigés |
| `AI_TREND_MIN_SAMPLES` | 20 | Volume minimal avant de conclure sur la qualité |
| `AI_TREND_MIN_SUCCESS_RATE` | 0,98 | Taux de succès sur la fenêtre de référence |
| `AI_TREND_MAX_FALLBACK_RATE` | 0,10 | Taux de fallback toléré |
| `AI_TREND_MAX_P95_MS` | 20 000 | Latence P95 tolérée |
| `AI_TREND_MAX_DAILY_COST_EUR` | désactivé | Plafond de coût journalier si défini |

En dessous du volume minimal, le script ne déclare **pas** les seuils tenus :
il signale `volume insuffisant`. Une absence de trafic ne peut donc jamais
être présentée comme une preuve de qualité.

## État

L'outillage est en place et couvert par des tests
(`tools/quality/check_ai_metrics_trend.test.mjs`, huit scénarios dont
l'accumulation insuffisante, le volume trop faible, la dégradation du taux de
succès, du fallback et de la latence).

La fenêtre de production accumulée n'atteint pas encore
`AI_TREND_MIN_OBSERVED_DAYS`. Le contrôle `metrics-accumulation` reste donc
`in_progress` jusqu'à ce qu'un artefact quotidien affiche
`accumulationComplete: true` et `gateFailures: []`.
