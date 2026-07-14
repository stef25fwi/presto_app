# Phase 1 — Architecture Flutter et découpage des grands écrans

## Objectif

Rendre le découpage mesurable et empêcher les régressions pendant la migration progressive.

Cibles de référence :

- écrans principaux : moins de 500 lignes ;
- widgets réutilisables : moins de 250 lignes ;
- UI, orchestration, domaine et accès données séparés ;
- extraction par tests de caractérisation puis déplacement incrémental.

## Baseline actuelle contrôlée

| Fichier | Lignes | Cible | Module | Prochaine extraction |
| --- | ---: | ---: | --- | --- |
| `lib/pages/publish_offer_page.dart` | 5131 | 500 | publication | orchestration IA, sections de formulaire, policies transcript, accès données |
| `lib/pages/consult_offers_page.dart` | 4139 | 500 | consultation | filtres, pagination, mapping offres, widgets de liste |
| `lib/pages/offers/offer_details_page.dart` | 4616 | 500 | détail offre | modèles UI, actions annonceur, rendu médias, bloc contact |
| `lib/pages/publish_offer_widgets.dart` | 287 | 250 | publication widgets | diagnostic IA et bannière validation |

Ces dépassements sont acceptés uniquement comme dette existante. Le contrôle CI échoue si :

1. un nouveau fichier Flutter dépasse sa limite ;
2. un fichier de la baseline grossit au-delà de son nombre de lignes actuel ;
3. une extraction est faite puis régressée ensuite.

## Commande locale

```bash
python3 tools/quality/check_flutter_architecture_size.py --enforce
```

## Chaîne de découpage recommandée

1. Ajouter ou stabiliser les tests de caractérisation de l’écran ciblé.
2. Extraire les décisions pures vers `features/<module>/domain` ou `services`.
3. Extraire les widgets stateless vers `features/<module>/presentation/widgets`.
4. Extraire l’orchestration vers un contrôleur/service testable.
5. Réduire le fichier page jusqu’à la cible.
6. Mettre à jour la baseline en diminuant `current_lines`, jamais en l’augmentant sans justification.

## Prochain lot conseillé

Premier lot à fort retour : `publish_offer_page.dart`.

Extraction prioritaire :

- policy de transcription et budget ;
- orchestration micro-IA ;
- état du flux IA ;
- sections visuelles déjà partiellement isolées ;
- accès Firestore/Functions derrière services injectables.
