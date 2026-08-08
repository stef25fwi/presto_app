# Lot 3 — Code mort — publish_offer_page.dart

Objectif de cette tranche : retirer le masque local `unused_element, unused_field, unused_local_variable, unused_element_parameter` de `lib/pages/publish_offer_page.dart`, laisser l’analyseur exposer les éléments réellement morts, puis supprimer uniquement ces éléments sans modifier le comportement fonctionnel.

Base de départ : `07ca73301242f4d1f53ff2e42f81541d18cdf21e` (`main` après fusion de #1307).

Contraintes : aucun seuil qualité abaissé, aucun skip/exclude ajouté, aucune modification Auth/App Check/Firebase/Firestore/Functions/routes/deep links. Fusion uniquement après validation complète du SHA final.
