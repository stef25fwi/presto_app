# Schéma Firestore — parcoursFiches

Pack généré le 2026-07-07 à partir de `statut_fonctionnaire.md`.

## Collection conseillée

`parcoursFiches`

## Document ID

`id_fiche`, exemple : `fonctionnaire_service_en_salle`

## Champs principaux

- `id_fiche`
- `titre`
- `statut_utilisateur`
- `categorie`
- `activite`
- `famille`
- `type_activite`
- `activite_reglementee`
- `niveau_vigilance`
- `code_ape_indicatif`
- `qualification_regles`
- `alertes`
- `documents_a_collecter`
- `parcours`
- `sources_officielles`
- `version`
- `legal_review_status`

## Requête type dans Flutter

```dart
final snap = await FirebaseFirestore.instance
    .collection('parcoursFiches')
    .where('statut_utilisateur', isEqualTo: 'fonctionnaire')
    .where('activite', isEqualTo: selectedActivity)
    .limit(1)
    .get();
```

## Principe UI

Quand l'utilisateur choisit :

1. Région
2. Statut = Fonctionnaire
3. Activité = une des activités du menu

l'application récupère la fiche correspondante et remplit :

- règles activité ;
- vérification situation personnelle ;
- statut conseillé ;
- démarches étape par étape ;
- aides ;
- coûts ;
- plan d'action 30 jours ;
- alertes juridiques.

## Important

Les fiches intègrent un socle officiel 2026 et des alertes métier. Pour une mise en production juridique complète, contrôler les fiches sensibles avec l'organisme compétent : administration employeur, CMA, CCI, DDPP/DAAF, Nova SAP, CNAPS, DREAL/DEAL, mairie ou assureur.
