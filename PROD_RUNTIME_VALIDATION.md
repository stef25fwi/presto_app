# VALIDATION PROD RUNTIME

Date: 2026-04-09

Objectif:
- verifier les parcours critiques apres remise a niveau progressive
- distinguer ce qui est couvert par l'analyse/test et ce qui reste manuel
- eviter les regressions sur les flux metier actifs

## Verifications automatisees minimales

Commandes a lancer depuis le repo:
- flutter analyze
- flutter test test/app_route_parser_test.dart
- flutter test test/conversation_state_test.dart
- flutter test test/publish_offer_test.dart

## Checklist manuelle priorite haute

### 1. Accueil vers detail annonce
- ouvrir l'app sur l'accueil
- verifier que les cartes recentes se chargent
- ouvrir une annonce depuis l'accueil
- verifier que le detail s'affiche sans ecran vide
- verifier que le retour navigation revient sur l'accueil

Attendu:
- pas de bouton silencieux
- pas de message faux positif
- en debug, logs Runtime sur ouverture detail

### 2. Detail annonce vers message, favori et signalement
- depuis une annonce, ouvrir message avec compte connecte
- verifier qu'une conversation s'ouvre ou se reprend correctement
- ajouter puis retirer le favori
- ouvrir le signalement, tester annulation puis envoi

Attendu:
- utilisateur non connecte: message honnete
- auto-message: blocage honnete
- favori: snackbar succes/erreur coherent
- signalement: annulation et erreurs tracees proprement

### 3. Publication avec selection de photos
- ouvrir Publier une offre
- selectionner une ou plusieurs photos
- verifier absence d'erreur silencieuse
- publier une annonce de test

Attendu:
- erreur de selection photo: snackbar erreur explicite
- publication: logs publish tap-submit, submit-start, submit-success ou submit-failure
- aucune navigation apres await sans garde mounted visible

### 4. Notifications a chaud et a froid
- envoyer une notification push vers une route messages ou offers
- tester avec app deja ouverte
- tester avec app lancee depuis la notification

Attendu:
- si navigator non pret, la route est queuee puis ouverte apres readiness
- pas de double ouverture immediate de la meme route
- logs notifications queue-route puis push-route si necessaire

### 5. Acces admin autorise et non autorise
- ouvrir Compte avec un compte admin autorise
- verifier ouverture Espace admin
- repeter avec un compte non autorise

Attendu:
- compte autorise: ecran admin charge proprement
- compte non autorise: refus explicite, pas de faux succes

## Checklist manuelle priorite moyenne

### Bootstrap Firebase web et mobile
- verifier lancement web
- verifier lancement mobile Android/iOS si environnements natifs disponibles
- verifier token FCM et App Check selon plateforme

### Lecture annonces publiques avec erreur backend
- provoquer ou simuler une erreur Firestore/App Check/index
- verifier message utilisateur honnete dans accueil et consulter
- verifier presence du debug card uniquement en debug

## Notes d'architecture

- listings est la source canonique et unique du catalogue public d'annonces
- offers legacy reste reserve aux compatibilites residuelles hors catalogue public
- sur le web, une absence de `APPCHECK_RECAPTCHA_SITE_KEY` ne doit pas casser la simple lecture publique des annonces; elle doit seulement empecher l'activation App Check stricte tant qu'aucun enforce n'est requis
- les notifications attendent desormais explicitement la disponibilite du navigator avant push