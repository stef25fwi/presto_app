# Couverture messagerie — vague 3

Cible unique : `lib/pages/messages/conversations_list_page.dart` et ses dépendances directes de messagerie.

Contraintes :
- partir du commit `main` a11861be14ee8e850f3eb357aeaa123b9a787ccb ;
- ajouter des tests widget et service déterministes couvrant les états connecté, vide, chargement, erreur, recherche, archivage, blocage et suppression ;
- mesurer avec `flutter test --coverage` ;
- ne pas abaisser les seuils ;
- ne pas ajouter d’exclusion LCOV, de `skip` ou de test factice ;
- conserver une seule branche et une seule PR active pour cette vague.

La PR doit rester ouverte jusqu’à validation complète du gain LCOV réel et de tous les workflows.
