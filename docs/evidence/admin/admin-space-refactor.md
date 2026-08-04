# Maintenabilité de l’espace d’administration — point 9

## Point de départ

`lib/pages/admin_space_page.dart` comptait **5 777 lignes** pour un budget
d’écran de 500. Le fichier mêlait quatre écrans complets, les modèles et le
calcul du tableau de bord, un service de configuration, les formateurs
partagés et une trentaine de widgets.

## Découpage réalisé

Le fichier est devenu une bibliothèque avec **18 fragments `part`** dans
`lib/pages/admin_space/`. Le code est déplacé tel quel : aucun type ne change
de visibilité, aucune signature n’est modifiée, aucun import n’est ajouté —
les fragments partagent ceux de la bibliothèque.

| Fragment | Contenu | Lignes |
|---|---|---:|
| `admin_space_deploy_diagnostic.dart` | Règles de diagnostic de déploiement | 127 |
| `admin_space_messaging_moderation.dart` | Mode de modération messagerie | 343 |
| `admin_space_metric_domains.dart` | Domaines suivis par le tableau de bord | 106 |
| `admin_space_micro_ia_page.dart` | Écran de réglage Micro IA | 314 |
| `admin_space_formatters.dart` | Formatage et agrégation partagés | 213 |
| `admin_space_dashboard_windows.dart` | Fenêtres et statistiques élémentaires | 91 |
| `admin_space_dashboard_computed.dart` | Calcul des indicateurs consolidés | 559 |
| `admin_space_email_dashboard.dart` | Tableau de bord e-mail | 177 |
| `admin_space_email_dashboard_content.dart` | Contenu et feuilles de détail | 439 |
| `admin_space_broadcast_page.dart` | Écrans audio et diffusion | 340 |
| `admin_space_dashboard_section.dart` | Section tableau de bord | 475 |
| `admin_space_dashboard_cards.dart` | Cartes, graphiques et pastilles | 261 |
| `admin_space_profile_card.dart` | Carte de profil administrateur | 161 |
| `admin_space_state_widgets.dart` | États d’information et écrans vides | 118 |
| `admin_space_shell_widgets.dart` | Cartes d’action et éléments de liste | 158 |
| `admin_space_cards.dart` | Cartes messagerie, badges, tuiles | 391 |
| `admin_space_micro_ia_card.dart` | Carte de pilotage Micro IA | 354 |
| `admin_space_chips.dart` | Boutons segmentés, chips, coquille | 146 |

Le fichier principal passe de **5 777 à 1 113 lignes** : imports, directives
`part`, `AdminSpacePage` et son `State`.

## Vérification

```bash
flutter analyze --fatal-infos      # Aucun problème
flutter test --reporter expanded
python3 tools/quality/check_flutter_architecture_size.py
```

Le contrôle de taille recensait 42 fichiers hors budget avant l’opération et
en recense 35 après, sans qu’aucun fragment nouvellement créé ne dépasse son
propre budget.

## Ce qui n’a pas été fait, et pourquoi

Deux fichiers restent au-dessus du budget et sont inscrits comme dérogations
datées dans `quality/flutter_architecture_size_budget.json`.

**`admin_space_page.dart` (1 113 lignes).** Le reste est `_AdminSpacePageState`.
Une classe ne peut pas être scindée par `part`. La tentative de la déporter
dans une extension a été abandonnée après vérification : le compilateur refuse
l’appel de `setState` depuis une extension (`invalid_use_of_protected_member`)
et exige la qualification des membres statiques du type étendu
(`unqualified_reference_to_static_member_of_extended_type`). La suite passe
donc par l’extraction de vrais widgets à paramètres explicites — un
changement de conception, pas un déplacement de code.

**`admin_space_dashboard_computed.dart` (559 lignes).** La classe est un
porteur de données de 43 lignes suivi d’une fabrique de 500 lignes. La
découper suppose d’extraire les agrégations par domaine en fonctions
testables ; fait à l’aveugle, sans test couvrant ce calcul, ce serait un
risque de régression pour un gain de 59 lignes.

Les deux suites sont rattachées au point 3 (architecture technique), qui a la
dette de découpage dans son périmètre. Le contrôle
`admin-screen-maintainability` du registre du point 9 reste `in_progress` :
l’écran est redevenu lisible, il n’est pas encore sous le budget.
