# Lot 3 — Code mort — certification

Date de certification candidate : 2026-08-08.

## Périmètre

Le Lot 1 LCOV reste en pause. Cette certification n'ajoute, ne relance et ne fusionne aucune mission LCOV.

Le Lot 3 vise à supprimer le code réellement mort sans modifier les comportements applicatifs, les routes, Auth, App Check, Firebase, Firestore, Functions ou les deep links.

## Travaux intégrés avant cette certification

Les tranches Lot 3 déjà fusionnées ont notamment :

- supprimé les exports de compatibilité devenus inutiles de `lib/main.dart` après le découplage complet certifié au Lot 2 ;
- supprimé une ancienne configuration Google Places sans consommateur ;
- supprimé des wrappers, helpers, constantes, variables et états privés sans lecture ni appel ;
- retiré progressivement les masques locaux `unused_*` ;
- retiré les masques globaux `unused_field` puis `unused_element` afin que l'analyseur expose à nouveau le code mort réel ;
- supprimé une archive manuelle `dev/archive/main_fixed.dart` devenue sans consommateur.

## État statique à certifier

- `analysis_options.yaml` ne masque plus `unused_field` ni `unused_element` ;
- aucun nouveau skip, exclusion LCOV ou baisse de seuil n'est introduit par cette certification ;
- les occurrences `unused_*` restantes observées dans `lib/l10n/app_localizations_*.dart` appartiennent aux fichiers générés par Flutter gen-l10n et ne doivent pas être éditées manuellement ;
- le composition root `main.dart` reste découplé conformément aux garde-fous du Lot 2.

## Critère de certification

Cette PR ne doit être fusionnée que si les contrôles requis du SHA exact sont verts, notamment :

- Pull request validation ;
- Flutter architecture size ;
- Analyzer ignore quality ;
- Dart format quality ;
- Production guardrails ;
- CodeQL ;
- contrôles Firebase/App Check/Firestore applicables au dépôt.

La certification du Lot 3 est acquise uniquement après fusion de ce SHA validé dans `main`. Si un contrôle révèle encore du code mort ou un masque non justifié, la PR doit être corrigée avant fusion.
