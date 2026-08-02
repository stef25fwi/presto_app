# Preuve — Recherche et pagination Marketplace

## Consultation publique

- tri stable par `createdAt desc` ;
- première page bornée ;
- curseur `startAfterDocument` ;
- dédoublonnage par identifiant ;
- page maximum 100 et plafond de session ;
- filtres catégorie, ville, département, région et texte normalisé.

## Mes annonces

- flux temps réel limité aux 20 annonces les plus récentes ;
- pages suivantes par `updatedAt desc` et curseur ;
- fusion sans doublon ;
- bouton de chargement seulement lorsqu’une page suivante existe.

## Favoris

- collection canonique `users/{uid}/favorites` triée par `createdAt desc` ;
- pages de 20, maximum 50 par requête ;
- lectures d’annonces groupées par `documentId whereIn` ;
- fallback legacy limité à une page de migration.

Le garde-fou bloque tout retour à un stream propriétaire sans limite ou à `.limit(500)`.
