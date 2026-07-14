# Playbook support production iliprestō

## Priorités

- P0 : paiement erroné, fuite de données, indisponibilité générale, suppression irréversible.
- P1 : connexion impossible pour plusieurs utilisateurs, publication bloquée, webhook Stripe en échec répété.
- P2 : fonction dégradée avec contournement disponible.
- P3 : question, défaut visuel ou demande non urgente.

## Réponse initiale

- P0 : accusé de réception sous 15 minutes.
- P1 : sous 1 heure.
- P2 : sous 1 jour ouvré.
- P3 : sous 2 jours ouvrés.

Ne jamais promettre une résolution avant diagnostic.

## Informations à collecter

- date et heure avec fuseau ;
- plateforme, navigateur et version de l'application ;
- identifiant utilisateur non sensible ;
- étapes de reproduction ;
- capture d'écran sans donnée bancaire ni mot de passe ;
- identifiant paiement Stripe ou facture lorsque pertinent ;
- impact et nombre d'utilisateurs concernés.

## Triage

1. Vérifier les dashboards Firebase, Functions, Stripe et support.
2. Identifier le dernier déploiement et son SHA.
3. Reproduire sans modifier de données réelles.
4. Classer P0 à P3.
5. Ouvrir un incident technique pour P0/P1.
6. Assigner un responsable et une prochaine heure de mise à jour.

## Paiements

- Ne jamais rembourser ou recréer un abonnement sans vérifier Stripe et Firestore.
- Contrôler l'idempotence et l'ordre des événements webhook.
- Conserver l'identifiant de paiement, d'abonnement, de facture et d'événement.
- En cas de doute, bloquer l'action automatique et escalader au responsable Stripe.

## Communication

Chaque mise à jour contient : impact connu, action en cours, contournement éventuel et heure de la prochaine mise à jour. Ne pas exposer de détails de sécurité ni de données personnelles.

## Clôture

- confirmer le retour au service ;
- faire valider par l'utilisateur lorsque possible ;
- lier le correctif ou le run de rollback ;
- documenter la cause racine ;
- créer les actions préventives ;
- fermer uniquement lorsque les métriques sont stables.
