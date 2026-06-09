# Stratégie données régionales - iliprestō

## Objectif

Permettre à chaque utilisateur résidant dans une région française d'obtenir des informations locales adaptées à son profil.

L'application doit afficher selon la région :

- CCI
- CMA
- Région ou collectivité compétente
- France Travail
- France Services
- organismes d'accompagnement
- aides publiques
- fiches projet adaptées

---

## Champs nécessaires dans le profil utilisateur

- region
- department
- city
- regionCode
- departmentCode

Exemple :

- region = Guadeloupe
- department = 971
- city = Baie-Mahault
- regionCode = guadeloupe
- departmentCode = 971

---

## Fichiers créés

- assets/data/business_guidance/france_regions.seed.json
- assets/data/business_guidance/local_resources.seed.json
- assets/data/business_guidance/official_sources.registry.json

---

## Services Flutter créés

- RegionNormalizer
- LocalBusinessGuidanceRepository

---

## Collections Firestore futures

- business_regions
- local_organizations
- public_aids
- business_project_templates
- business_project_sheets

---

## Statut des données

Les données générées à cette étape sont une base structurée.

Les champs téléphone, email, adresse, site web et URL officielles doivent être complétés et vérifiés avant publication.

Statuts recommandés :

- draft
- needs_review
- verified
- expired
- disabled

---

## Priorité de vérification

1. Guadeloupe
2. Martinique
3. Guyane
4. Réunion
5. Mayotte
6. Île-de-France
7. Provence-Alpes-Côte d'Azur
8. Auvergne-Rhône-Alpes
9. Nouvelle-Aquitaine
10. Occitanie

