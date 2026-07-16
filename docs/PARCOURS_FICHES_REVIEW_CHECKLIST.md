# Checklist de validation d'une fiche parcours

## 1. Cohérence métier

- [ ] Le nom, la famille et le type d'activité décrivent la même activité.
- [ ] Aucun bloc ne provient d'une activité voisine.
- [ ] Le code APE est présenté comme indicatif.
- [ ] Les qualifications, cartes, agréments et assurances sont applicables.
- [ ] Les organismes indiqués sont compétents pour cette activité.

## 2. Chronologie

- [ ] Le droit d'exercer est vérifié en premier.
- [ ] La situation de l'utilisateur est sécurisée avant la création.
- [ ] L'offre, les prix et le budget sont définis.
- [ ] Les aides à demander avant création sont vérifiées avant l'immatriculation.
- [ ] Le statut est choisi avant la préparation du dossier.
- [ ] La déclaration précède la première prestation.
- [ ] Assurance, devis et facturation sont prêts avant le premier client.
- [ ] Les obligations récurrentes sont regroupées après la création.

## 3. Personnalisation

- [ ] Les étapes inutiles sont masquées.
- [ ] Le territoire et le statut actuel modifient réellement le parcours.
- [ ] Les alertes correspondent au profil.
- [ ] Les courriers apparaissent uniquement lorsque nécessaires.

## 4. Fiabilité

- [ ] Chaque obligation importante possède une source officielle.
- [ ] Les valeurs évolutives sont datées.
- [ ] Les aides sont présentées sous conditions.
- [ ] Les dates `reviewed_at` et `next_review_at` sont renseignées.
- [ ] Le relecteur est identifié.

## 5. Lisibilité PDF

- [ ] Aucun doublon important n'est visible.
- [ ] Aucun libellé anglais n'apparaît dans la version française.
- [ ] Aucun titre n'est isolé en bas de page.
- [ ] Les liens sont cliquables et regroupés dans les sources.
- [ ] Les cases à cocher et résultats attendus sont lisibles.
- [ ] Le PDF a été vérifié avec au moins trois profils.

## Décision

- [ ] Audit automatique sans blocage ni erreur.
- [ ] Validation métier effectuée.
- [ ] Validation juridique effectuée lorsque le niveau de risque l'exige.
- [ ] Contrôle visuel effectué.
- [ ] `review_status` peut être passé à `validee`.
