# Palier analyzer — 9 règles ignorées

Ce palier réactive `unused_import` afin d'éliminer les imports devenus inutiles sans modifier le comportement métier.

La CI complète doit rester verte avant fusion. Toute violation révélée par `flutter analyze --fatal-infos` doit être corrigée de manière ciblée.
