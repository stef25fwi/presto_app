# Lot publication — U02 — 23 septembre 2026

## Problème traité

Le formulaire guidé masquait et bloquait les champs tant qu'une analyse IA
n'avait pas réussi. Une personne qui souhaite rédiger seule, ou qui rencontre
un problème d'accès à l'IA, ne pouvait pas compléter normalement son annonce.

## Comportement proposé

- Bouton explicite « Remplir sans l’IA » sous les méthodes vocal/texte.
- Description, titre, catégorie, photos, lieu, téléphone, délai, budget et
  bouton de publication accessibles immédiatement après ce choix.
- Le choix manuel conserve les champs déjà saisis et ne déclenche aucun
  traitement IA. La classification automatique des photos n'est pas lancée
  dans ce mode ; les contrôles et la modération serveur restent inchangés.
- L'aide IA demeure disponible sur demande. Un abandon de la connexion à
  l'IA ne ferme pas le formulaire manuel ni n'efface la saisie.
- Impossible d'activer le mode manuel pendant un enregistrement, une analyse,
  une classification photo ou une soumission en cours.
- Les validations, la connexion, App Check et la publication via le service
  existant sont conservés. Le mode manuel ne vaut pas validation de l'annonce.
- La réinitialisation confirmée efface les champs et revient au choix initial.

L'indication de guidage est extraite dans un widget afin de garder la page
sous son plafond de taille existant. Aucun seuil n'est relevé.

## Vérifications

Cinq scénarios Flutter sont ajoutés : accès réel aux champs et validations,
formulaire manuel complet jusqu'au contrôle de connexion, reprise du texte
guidé et abandon de l'aide IA sans perte, réinitialisation annulée/confirmée,
bouton occupé et affichage à 320 px avec texte agrandi.

Le contrôle de taille d'architecture et `git diff --check` passent localement.
Flutter n'étant pas disponible dans l'environnement local, l'analyse, ces
scénarios, la suite complète et le build web doivent passer en CI sur le SHA
de cette PR. Aucun test de publication réelle avec compte n'a été réalisé.

## Articulation avec les autres lots

Les PR #1458 (sécurité et conservation du brouillon entre onglets) et #1459
(inventaire de préparation sécurité) ont toutes leurs exécutions CI vertes,
respectivement sur `ef49c87a` et `b6655b25`, et sont prêtes pour revue.
Le présent lot est indépendant et ne remplace pas #1458 : la sauvegarde
durable du brouillon après fermeture/rechargement reste à traiter (U01).

S04 et les preuves externes S05 restent ouverts. Les prochains lots concernent
les filtres/pagination/compteurs (U03–U05), les anciennes annonces publiques
(S06), puis l'accessibilité et les performances.

Le hero Home et ses trois affiches ne sont pas modifiés. Aucune fusion ni
mise en production n'est réalisée dans ce lot.
