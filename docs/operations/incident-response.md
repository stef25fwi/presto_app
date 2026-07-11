# Réponse aux incidents

## Niveaux

| Niveau | Définition | Exemples |
|---|---|---|
| SEV-1 | Service indisponible ou risque majeur de sécurité/données | écran blanc global, fuite de données, paiements incorrects |
| SEV-2 | Parcours critique fortement dégradé | publication, connexion ou messagerie inutilisable pour une part importante des utilisateurs |
| SEV-3 | Fonction secondaire dégradée avec contournement | filtre, image, notification ou affichage partiel |

## Première réponse

1. Confirmer l’incident avec une preuve reproductible.
2. Noter l’heure, la version, la plateforme, le territoire et le parcours.
3. Vérifier les dernières releases et changements de configuration.
4. Consulter Crashlytics, Performance, logs Functions, Firestore et webhooks.
5. Réduire l’impact : désactivation Remote Config, rollback ou suspension ciblée.
6. Informer les personnes concernées avec des faits vérifiés.

## Rôles minimaux

- **Incident commander** : décide et tient la chronologie.
- **Responsable technique** : diagnostic et correction.
- **Responsable communication** : message utilisateurs/partenaires si nécessaire.
- **Scribe** : conserve décisions, commandes, métriques et résultats.

Une petite équipe peut cumuler les rôles, mais les responsabilités doivent rester explicites.

## Informations à collecter

- commit et workflow de déploiement ;
- version Flutter et plateforme ;
- URL ou Function concernée ;
- taux d’erreur, latence et nombre d’utilisateurs affectés ;
- identifiants de corrélation sans données personnelles ;
- statut Auth, App Check, Firestore, Storage, Stripe, FCM et email ;
- changement de règles, index, secrets ou Remote Config.

## Communication

Ne jamais annoncer une cause avant confirmation. Indiquer l’impact observé, les parcours concernés, les mesures prises et la prochaine mise à jour. Ne publier aucun secret, identifiant personnel ou contenu utilisateur.

## Clôture

Un incident est clôturé lorsque le service est stable, les métriques sont revenues à la normale, la cause est comprise et les actions préventives sont suivies dans GitHub Issues.

Le compte rendu doit inclure :

- chronologie ;
- cause racine ;
- facteurs contributifs ;
- raison de la non-détection préalable ;
- correction et rollback éventuel ;
- tests, alertes et documentation ajoutés ;
- propriétaires et échéances des actions.
