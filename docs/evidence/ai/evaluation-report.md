# Rapport d’évaluation IA — point 8

## Portée

Cette preuve couvre les trois familles obligatoires :

- transcription audio ;
- génération structurée d’annonce à partir de texte ou transcription ;
- analyse d’image.

## Corpus synthétique

Le corpus est versionné dans `functions/evals/` et régénéré à l’identique par
`npm --prefix functions run ai:eval:media` (espeak-ng pour la voix, ffmpeg
pour le transcodage). Les médias eux-mêmes ne sont pas versionnés : seuls les
manifestes le sont, et `evals/media/manifest.json` enregistre pour chaque cas
sa durée, sa taille et son empreinte SHA-256.

### Couverture audio

| Accent | Cas | Conteneurs exercés |
|---|---:|---|
| fr-FR | 5 | wav, mp3, m4a, flac, ogg |
| fr-BE | 2 | ogg, mp3 |
| fr-CH | 2 | webm, wav |

Les six conteneurs acceptés par la Micro IA — `wav`, `mp3`, `ogg`, `webm`,
`flac`, `m4a` — sont couverts, ainsi que trois débits de parole (120, 145 et
170 mots/minute) et des timbres distincts via les variantes de voix.

### Couverture image

`jpg`, `png` et `webp`, soit les trois types acceptés par la classification
photo, dont un cas volontairement ambigu servant à mesurer les hallucinations.

### Contrôle automatique

`tools/quality/check_ai_eval_corpus.mjs` refuse un corpus qui perdrait un
accent, un conteneur, son cas ambigu, ou dont un type MIME ne correspondrait
plus au conteneur produit. Il tourne dans le workflow `AI evaluations` et est
lui-même couvert par `check_ai_eval_corpus.test.mjs`.

## Commandes reproductibles

```bash
npm --prefix functions run build
npm --prefix functions test
npm --prefix functions run ai:eval:media
npm --prefix functions run ai:eval:transcription:dry
npm --prefix functions run ai:eval:vision:dry
npm --prefix functions run ai:prompt:tokens
node tools/quality/check_ai_eval_corpus.mjs
```

Les évaluations réelles nécessitant OpenAI sont exécutées uniquement avec le
secret serveur prévu :

```bash
npm --prefix functions run ai:eval:listing
npm --prefix functions run ai:eval:transcription
npm --prefix functions run ai:eval:vision
```

Elles tournent automatiquement chaque lundi à 05:00 UTC (workflow
`AI evaluations`, job `live`), à chaque `push` sur `main` touchant la chaîne
IA, et à la demande. Les rapports sont archivés 90 jours.

## Seuils de certification

### Seuils globaux

| Variable | Défaut | Famille |
|---|---:|---|
| `AI_EVAL_MAX_WER` | 0,35 | Audio |
| `AI_EVAL_MAX_ENTITY_ERROR_RATE` | 0,20 | Audio |
| `AI_EVAL_MAX_HALLUCINATION_RATE` | 0,25 | Audio |
| `AI_EVAL_MIN_VISION_ACCURACY` | 0,66 | Vision |
| `AI_EVAL_MAX_VISION_HALLUCINATION_RATE` | 0,10 | Vision |
| `AI_EVAL_MIN_SCHEMA_VALID_RATE` | 1,00 | Texte et vision |
| `AI_EVAL_MAX_P95_MS` | 60 000 / 30 000 | Audio / vision |

### Seuils par groupe

Une moyenne globale acceptable peut masquer un accent ou un conteneur
dégradé. Le harnais agrège donc aussi par accent et par format, et applique
des plafonds propres à chaque groupe :

| Variable | Défaut |
|---|---:|
| `AI_EVAL_MAX_GROUP_WER` | 0,45 |
| `AI_EVAL_MAX_GROUP_ENTITY_ERROR_RATE` | 0,34 |

Côté vision, la validité de schéma est vérifiée format par format.
Une couverture incomplète est elle-même un échec de gate, jamais une simple
statistique.

## Règles

- aucun média utilisateur réel n’est ajouté au dépôt ;
- le corpus synthétique doit être versionné et reproductible ;
- chaque rapport final mentionne le SHA, les modèles, la date et les paramètres ;
- un changement de modèle ou de prompt invalide la preuve précédente ;
- une sortie non conforme au schéma est comptée comme échec, jamais réparée silencieusement dans le rapport ;
- les résultats réels doivent être archivés comme artefacts CI avant passage des contrôles à `verified`.

## État

Acquis et vérifiables hors production :

- couverture du corpus (accents, conteneurs audio, formats image) — contrôle
  `eval-corpus-coverage` à `verified` ;
- mesure de durée audio sur les six conteneurs, validée sur des fichiers
  réellement encodés par ffmpeg — contrôle `audio-duration-coverage` à
  `verified` ;
- seuils par groupe et gates de couverture, couverts par
  `tools/quality/check_ai_eval_corpus.test.mjs`.

Restent à produire :

- les résultats réels audio, texte et vision associés au SHA candidat, d’où
  les contrôles `audio-evaluation`, `text-evaluation` et `vision-evaluation`
  maintenus `pending` ;
- au moins une exécution planifiée archivée, d’où `scheduled-evaluations`
  maintenu `in_progress`.
