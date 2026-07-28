# Mode d’exploitation à coût minimum

Ce mode est la configuration par défaut de la bêta gratuite iliprestō.

## Résultat attendu

- aucune instance Cloud Functions maintenue chaude ;
- deux tâches Cloud Scheduler au lieu de vingt-et-une ;
- Vertex AI absent des dépendances et des chemins d’exécution ;
- Veo fermé par défaut et protégé par un quota mensuel lorsqu’il est réactivé ;
- Micro IA limitée à Google Speech-to-Text, sans fallback Whisper automatique ;
- appels OpenAI et durée audio protégés par des quotas mensuels globaux ;
- recherche d’adresse fournie par la Géoplateforme pour la métropole et les DOM ;
- médias redimensionnés en WebP et fichiers temporaires supprimés par les tâches existantes ;
- logs détaillés désactivés par défaut.

## Valeurs par défaut

Le code applique ces valeurs même si aucune variable n’est fournie :

| Variable | Valeur bêta | Effet |
| --- | ---: | --- |
| `MINIMUM_COST_MODE` | `true` | active tous les garde-fous |
| `FUNCTIONS_MIN_INSTANCES` | `0` | aucune instance chaude |
| `MICROIA_MAX_INSTANCES` | `2` | limite la concurrence vocale |
| `MICROIA_MONTHLY_AUDIO_SECONDS` | `3600` | 60 minutes audio par mois |
| `OPENAI_MONTHLY_REQUEST_LIMIT` | `2000` | plafond global OpenAI |
| `VEO_GENERATION_ENABLED` | `false` | aucune génération vidéo facturable |
| `VEO_MONTHLY_GENERATION_LIMIT` | `0` | quota Veo fermé |
| `VEO_MAX_INSTANCES` | `1` | une génération simultanée maximum |
| `COST_VERBOSE_LOGS` | `false` | évite les logs de diagnostic volumineux |
| `STRIPE_CATALOG_AUDIT_ENABLED` | `false` | pas d’audit Stripe périodique en bêta |

Les compteurs mensuels sont enregistrés dans la collection technique
`_cost_usage`. Ils ne contiennent pas de contenu utilisateur.

## Tâches planifiées

Seules les fonctions suivantes doivent être exportées :

- `runCostOptimizedMinuteTasks` : publication des annonces approuvées ;
- `runCostOptimizedQuarterHourTasks` : e-mails, nettoyages, statistiques et
  maintenance selon leurs horaires historiques.

Cloud Scheduler offre trois tâches par compte de facturation. Ces deux tâches
restent donc dans cette franchise tant qu’aucun autre projet du même compte ne
la consomme.

## Activation ultérieure de Veo

Veo ne peut être activé qu’en quittant explicitement le mode minimum :

```dotenv
MINIMUM_COST_MODE=false
VEO_GENERATION_ENABLED=true
VEO_MONTHLY_GENERATION_LIMIT=5
VEO_MAX_INSTANCES=1
```

Le quota est réservé avant l’appel au fournisseur. Une génération échouée reste
comptabilisée car elle peut avoir engagé un coût fournisseur.

## Budget Google Cloud

Aucune clé de service ne doit être copiée dans le dépôt ou communiquée dans un
chat. Depuis la console Google Cloud du projet `presto-app-74abe` :

1. ouvrir **Facturation → Budgets et alertes** ;
2. créer un budget mensuel de 5 USD ou son équivalent ;
3. activer les notifications à 50 %, 80 % et 100 % ;
4. activer un plafond de dépense pour Cloud Run, Cloud Run Functions et Gemini
   lorsque l’option est disponible sur le compte ;
5. vérifier les destinataires des alertes avant le déploiement.

Un budget standard alerte mais ne coupe pas toujours les services. Le quota
applicatif reste donc la protection principale.

## Validation

Depuis `functions/` :

```bash
npm ci
npm run cost:audit
npm test
```

Après déploiement, vérifier dans Cloud Scheduler qu’il ne reste que les deux
orchestrateurs et supprimer les anciens jobs seulement après validation de leur
première exécution réussie.
