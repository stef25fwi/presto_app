# Page Mon compte — séparation visuelle des sections

## Objectif

Améliorer la lisibilité de la page `Mon compte iliprestō` :

- supprimer le logo `assets/images/logowebp.webp` affiché immédiatement sous le header orange ;
- renforcer le contour gris de toutes les tuiles principales afin que chaque section soit clairement identifiable.

## Modifications attendues

### `lib/pages/account_page.dart`

Dans `_buildAccountSectionCard`, remplacer la bordure bleue très légère :

```dart
border: Border.all(color: kPrestoBlue.withValues(alpha: 0.10)),
```

par une bordure grise plus visible :

```dart
border: Border.all(
  color: const Color(0xFFB8BEC7),
  width: 2,
),
```

Dans la colonne principale située juste sous l’`AppBar`, supprimer entièrement le bloc :

```dart
// Logo brand centré
Padding(
  padding: const EdgeInsets.only(top: 10, bottom: 12),
  child: Center(
    child: Image.asset(
      'assets/images/logowebp.webp',
      height: 52,
    ),
  ),
),
```

Le premier élément sous le header doit devenir `_buildDefaultHeader(...)`.

### `lib/widgets/account_notifications_tile.dart`

Dans le `RoundedRectangleBorder`, renforcer la bordure pour garder la même séparation visuelle que les autres sections :

```dart
side: const BorderSide(
  color: Color(0xFFB8BEC7),
  width: 2,
),
```

## Validation

- `dart format lib/pages/account_page.dart lib/widgets/account_notifications_tile.dart`
- `flutter analyze --no-pub`
- tests widget de la page compte s’ils existent ;
- aucune modification fonctionnelle ;
- aucune baisse de seuil ou exclusion de couverture.
