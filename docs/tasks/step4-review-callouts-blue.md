# Étape 4 — uniformiser les tuiles de vérification

## Objectif

Dans `lib/pages/toolbox_je_me_lance_page.dart`, sur l’étape 4 « Vérifiez avant validation », remplacer les tons violet et vert par le même bleu que la tuile « Territoire pris en compte ».

## Modification exacte

Dans `_buildReviewStep()` :

```dart
_ResultCallout(
  icon: Icons.badge_outlined,
  title: 'Statut actuel',
  text: _situation.isNotEmpty ? _situation : 'Aucun statut renseigné',
  tone: const Color(0xFF7C3AED),
),
```

remplacer par :

```dart
_ResultCallout(
  icon: Icons.badge_outlined,
  title: 'Statut actuel',
  text: _situation.isNotEmpty ? _situation : 'Aucun statut renseigné',
  tone: kBlue,
),
```

Et remplacer :

```dart
_ResultCallout(
  icon: Icons.work_outline_rounded,
  title: 'Activité',
  text: _selectedActivity.isNotEmpty
      ? _selectedActivity
      : 'Aucune activité renseignée',
  tone: const Color(0xFF26A65B),
),
```

par :

```dart
_ResultCallout(
  icon: Icons.work_outline_rounded,
  title: 'Activité',
  text: _selectedActivity.isNotEmpty
      ? _selectedActivity
      : 'Aucune activité renseignée',
  tone: kBlue,
),
```

## Résultat attendu

Les trois tuiles suivantes utilisent exactement le même bleu clair :

- Territoire pris en compte ;
- Statut actuel ;
- Activité.

## Validation

- `dart format lib/pages/toolbox_je_me_lance_page.dart`
- `flutter analyze --no-pub`
- vérification visuelle de l’étape 4 ;
- aucun changement fonctionnel.
