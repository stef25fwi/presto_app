# Stratégie de cache

## Principe

Le cache améliore la vitesse et réduit les lectures Firestore, mais il ne remplace jamais la source de vérité. Chaque donnée mise en cache doit avoir une clé, une durée de vie, une méthode d’invalidation et un comportement hors ligne explicites.

## Niveaux

| Niveau | Usage | Exemples |
|---|---|---|
| Mémoire | Données réutilisées pendant une session | catégories, plans, droits calculés, configuration |
| Local persistant | Préférences et brouillons non sensibles | filtres, brouillon d’annonce, parcours sauvegardé |
| Firestore offline | Continuité temporaire du SDK | documents récemment lus |
| Backend agrégé | Résultats coûteux partagés | statistiques admin, compteurs, résumés |

## Composant mémoire

`ExpiringMemoryCache<K, V>` fournit :

- TTL par défaut ou par entrée ;
- éviction bornée de type LRU ;
- invalidation ciblée ;
- purge des entrées expirées ;
- `getOrLoad` pour éviter une lecture répétée ;
- horloge injectable pour des tests déterministes.

## Politique initiale

| Ressource | TTL indicatif | Invalidation | Source de vérité |
|---|---:|---|---|
| Catégories et sous-catégories | 24 h | changement de version catalogue | Firestore / assets versionnés |
| Plans d’abonnement publics | 15 min | webhook/configuration tarifaire | Backend Stripe/Firebase |
| Profil courant | 5 min | modification du profil ou déconnexion | Firestore |
| Droits d’abonnement | 1 min maximum | webhook, retour checkout, reconnexion | Backend |
| Remote Config | selon SDK | activation d’une nouvelle configuration | Firebase Remote Config |
| Statistiques admin | 1 à 5 min | écriture agrégée | documents d’agrégat |

Les droits de paiement ne doivent jamais être accordés à partir d’une valeur locale obsolète. Le backend reste autoritaire.

## Invalidation

Déclencher une invalidation lors de :

- déconnexion ou changement de compte ;
- mise à jour réussie de la ressource ;
- webhook d’abonnement traité ;
- changement de version de catalogue ;
- suppression administrative ;
- changement de territoire ou de rôle.

## Mesures

Suivre :

- taux de hit/miss ;
- lectures Firestore par utilisateur actif ;
- temps de chargement avant/après cache ;
- taille du cache ;
- âge des données utilisées ;
- erreurs dues à une invalidation manquante.

## Interdictions

- conserver durablement des secrets ou moyens de paiement ;
- utiliser un cache client pour autoriser une opération sensible ;
- créer un cache sans limite de taille ;
- utiliser un TTL infini sans version ou invalidation ;
- masquer une erreur réseau en présentant une donnée obsolète comme fraîche.
