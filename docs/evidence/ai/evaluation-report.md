# Rapport d’évaluation IA — point 8

## Portée

Cette preuve couvre les trois familles obligatoires :

- transcription audio ;
- génération structurée d’annonce à partir de texte ou transcription ;
- analyse d’image.

## Commandes reproductibles

```bash
npm --prefix functions run build
npm --prefix functions test
npm --prefix functions run ai:eval:media
npm --prefix functions run ai:eval:transcription:dry
npm --prefix functions run ai:eval:vision:dry
npm --prefix functions run ai:prompt:tokens
```

Les évaluations réelles nécessitant OpenAI sont exécutées uniquement avec le secret serveur prévu :

```bash
npm --prefix functions run ai:eval:listing
npm --prefix functions run ai:eval:transcription
npm --prefix functions run ai:eval:vision
```

## Critères de certification

| Famille | Mesures obligatoires | État |
|---|---|---|
| Audio | WER, entités utiles, transcription vide, latences P50/P90/P95/P99, coût | À mesurer sur le SHA candidat |
| Texte | validité du schéma, champs requis, hallucinations, catégories, latence, tokens et coût | À mesurer sur le SHA candidat |
| Vision | validité du schéma, objets/catégories, hallucinations, erreurs média, latence et coût | À mesurer sur le SHA candidat |

## Règles

- aucun média utilisateur réel n’est ajouté au dépôt ;
- le corpus synthétique doit être versionné et reproductible ;
- chaque rapport final mentionne le SHA, les modèles, la date et les paramètres ;
- un changement de modèle ou de prompt invalide la preuve précédente ;
- une sortie non conforme au schéma est comptée comme échec, jamais réparée silencieusement dans le rapport ;
- les résultats réels doivent être archivés comme artefacts CI avant passage des contrôles à `verified`.

## État initial constaté

Le dépôt expose déjà les scripts d’évaluation audio, texte, vision, génération de médias synthétiques, rapport de tokens et métriques. Les résultats réels associés au SHA de cette PR restent à produire ; les contrôles correspondants demeurent donc `pending`.
