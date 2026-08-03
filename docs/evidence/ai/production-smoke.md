# Smoke test production IA — point 8

## Objectif

Prouver sur le même SHA déployé :

1. le traitement V2 nominal ;
2. le contrôle Auth et App Check ;
3. les métriques structurées sans contenu utilisateur ;
4. le fallback V1 ;
5. le rollback Remote Config sans redéploiement ;
6. la reprise V2 après retour à une configuration saine.

## Préconditions

- Functions déployées depuis le SHA candidat ;
- secret OpenAI disponible uniquement côté serveur ;
- compte de test Firebase dédié ;
- jeton App Check valide ;
- média synthétique sans donnée personnelle ;
- valeurs Remote Config sauvegardées avant le test.

## Séquence obligatoire

### A. V2 nominal

```text
micro_ia_v2_enabled = true
micro_ia_v2_rollout_percent = 100
micro_ia_v1_fallback_enabled = true
```

Exécuter :

```bash
npm --prefix functions run ai:smoke:production
```

Vérifier succès, schéma, identifiant de requête, latence, modèle, usage et absence de contenu sensible dans les logs.

### B. Rejet des appels non autorisés

Vérifier séparément :

- appel sans utilisateur authentifié ;
- appel sans App Check ;
- média hors bucket ou URL non autorisée ;
- média trop volumineux ou trop long.

Chaque cas doit échouer avec un code stable et sans appel OpenAI facturable.

### C. Fallback V1

Provoquer une erreur V2 éligible avec le mécanisme de test prévu, puis vérifier :

- une seule tentative utile par étape ;
- fallback V1 exécuté ;
- compteur `fallback` incrémenté ;
- résultat utilisable ou erreur finale stable ;
- aucune double facturation silencieuse.

### D. Rollback Remote Config

Publier :

```text
micro_ia_v2_enabled = false
micro_ia_v2_rollout_percent = 0
micro_ia_v1_fallback_enabled = true
```

Après rafraîchissement de la configuration, vérifier que le client n’appelle plus V2 et que V1 reste fonctionnel. Restaurer ensuite la configuration validée et répéter un test V2 nominal.

## Observabilité obligatoire

Le rapport final doit inclure, sans texte utilisateur :

- SHA déployé ;
- modèles et versions de prompts ;
- succès/échecs ;
- latences P50/P90/P95/P99 ;
- taux de fallback ;
- cache ;
- tokens entrée/sortie/cache ;
- durée audio ;
- coût estimé ;
- erreurs par code ;
- preuve d’exécution des purges planifiées.

## État initial

Le script de smoke production et le runbook existent déjà. La preuve d’un cycle complet V2 → fallback → rollback → reprise, associée au SHA candidat, n’est pas encore archivée. Les contrôles `production-smoke` et `remote-config-rollback` restent `pending`.
