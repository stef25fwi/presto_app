# Consultation : pagination filtrée et compteur (U03 / U05)

## Problème

Les filtres locaux désactivaient la pagination. La consultation s'arrêtait à
100 documents, même si des annonces plus anciennes correspondaient aux critères.
Le compteur sans filtre utilisait un agrégat différent des cartes affichées.

## Correction

- Pages successives de 20 annonces publiques actives, sans plafond global de 100.
- Filtres locaux compatibles avec la pagination ; bouton « Continuer la recherche »
  disponible même quand aucune carte de la page chargée ne correspond.
- Chargement au défilement conservé, temporisé ; aucun balayage automatique de
  toute la collection. Après une erreur, la reprise exige le bouton « Réessayer ».
- Compteur des annonces effectivement affichées, marqué « résultats partiels »
  tant que la requête canonique peut avoir une page suivante.
- Une génération de requête écarte les réponses obsolètes, y compris après
  actualisation avec les mêmes filtres. Les lectures simultanées sont évitées.
- Curseur issu exclusivement des annonces canoniques, jamais du backfill legacy.
- Suppression du préchargement initial redondant et du comptage agrégé séparé.
- Actualisation du compteur et du cache à l'expiration d'une annonce terminée.

## Vérification

Tests ajoutés : recherche dans 127 documents avec une correspondance au-delà de
100 ; curseur canonique et déduplication ; fin de pagination ; erreur et reprise ;
requêtes concurrentes ; changement de filtre et actualisation pendant un chargement ;
curseur immobile ; libellés du compteur. Tests widget du bouton sur écran 320 px
avec texte agrandi, chargement, reprise et fin de liste.

Le SDK Flutter n'est pas disponible localement. L'analyse, la suite Flutter et
la compilation web doivent être confirmées par la CI de la PR avant validation.

## Portée et limites

Le hero Home, ses trois affiches, les assets, les règles Firestore et la publication
ne sont pas modifiés. Aucun merge ni déploiement de production n'est effectué.
Le compteur est un nombre affiché, pas un total exhaustif de correspondances serveur.
La pagination complète concerne `listings` ; le fallback legacy existant reste
borné à son chargement initial. Sa migration relève du chantier S06.
U04 (comportement du panneau de filtres) reste un lot séparé.
