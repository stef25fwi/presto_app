# Parcours personnalisé guidé — implémentation

La page **Mon parcours personnalisé** utilise désormais un renderer unique pour
les parcours générés, repris et sauvegardés.

## Structure appliquée à toutes les fiches

1. aperçu global avec prochaine action ;
2. une seule étape active à la fois ;
3. huit étapes identiques pour toutes les fiches activité/statut ;
4. liens et organismes réellement cliquables ;
5. listes longues repliées après deux ressources ;
6. checklist et résultat attendu dans chaque étape ;
7. progression sauvegardée dans `guidedProgress` ;
8. reprise sur la dernière étape incomplète ;
9. conservation de toutes les informations et de l’export PDF existant.

## Étapes

1. Comprendre les règles de mon activité
2. Vérifier ma situation personnelle
3. Choisir mon cadre de lancement
4. Préparer mon dossier
5. Déclarer mon activité
6. Sécuriser mon lancement
7. Identifier les aides et mon budget
8. Suivre mon plan d’action sur 30 jours

## Compatibilité

Les anciennes fiches restent compatibles : le renderer transforme les clés
existantes `regulationTutorial`, `statusWarnings`, `recommendedLegalStatus`,
`steps`, `aides`, `costs` et `plan30` sans supprimer leur contenu.
