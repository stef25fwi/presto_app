# Videomaker administrateur — VEO

## Fonctionnement

L’espace administrateur expose une tuile **Videomaker**. La page permet :

- de saisir un prompt ;
- d’ajouter une image de départ facultative ;
- de choisir un format portrait `9:16` ou paysage `16:9` ;
- de lancer VEO 3.1 ;
- de consulter l’historique des vidéos ;
- d’ouvrir/télécharger et partager chaque vidéo.

Les vidéos terminées sont copiées dans Firebase Storage sous
`admin/videomaker/videos/`. Le lien de téléchargement Firebase est conservé
dans la collection serveur `_admin_video_maker_jobs`.

## Clé API

La clé saisie dans l’interface est envoyée uniquement à la Cloud Function,
n’est jamais écrite dans Firestore et est effacée du champ après la requête.
Pour éviter de la ressaisir, configurer le secret Firebase :

```bash
firebase functions:secrets:set VEO_API_KEY \
  --project presto-app-74abe
```

La clé doit avoir accès à l’API Gemini et à VEO, avec une facturation active.

## Déploiement ciblé

```bash
cd functions
npm ci
npm run build
cd ..

firebase deploy \
  --only functions:adminGenerateVideo,functions:adminListGeneratedVideos \
  --project presto-app-74abe
```

Le déploiement de l’interface Flutter suit ensuite le pipeline habituel.
