# Lot 3 — Code mort — user offers

Base : `92682b95614922c2f2243c3812118deac02b18e6`.

Cette tranche retire uniquement le masque fichier `unused_element, unused_field, unused_local_variable, unused_element_parameter` de `lib/pages/user_offers_section.dart`.

La PR finale doit être validée par `flutter analyze`, les tests, les garde-fous architecture/sécurité/Firestore/App Check et le build Web. Si l’analyseur révèle du code mort, la tranche doit être corrigée avant fusion ; aucun seuil, skip ou exclusion ne peut être ajouté.

Lot 1 LCOV reste en pause.
