# Lot 3 — Code mort — consult_offers_page.dart

Objectif de cette tranche : retirer le masque local `unused_element, unused_field, unused_local_variable` de `lib/pages/consult_offers_page.dart`, exposer les diagnostics réels de l’analyseur puis supprimer uniquement le code réellement mort si nécessaire.

Base de départ : `0ee2f1acefc1e3a41ae25d6a80e4d2b8d8cdd411` (`main` après fusion de #1308).

Contraintes : aucun seuil qualité abaissé, aucun skip/exclude ajouté, aucune modification Auth/App Check/Firebase/Firestore/Functions/routes/deep links. Fusion uniquement après validation complète du SHA final.
