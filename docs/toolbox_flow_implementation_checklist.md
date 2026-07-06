# Checklist technique — Implémentation du flow boîte à outils

## Objet

Ce document traduit la spec produit de [docs/toolbox_flow.md](/workspaces/presto_app/docs/toolbox_flow.md) en plan d'implémentation technique.

But : permettre une exécution écran par écran, avec composants, règles de données, états UI et checklist de validation.

## Périmètre

Le périmètre couvre 3 surfaces principales :

- page Boîte à outils
- page Je me lance
- page Mon parcours

La calculatrice entrepreneur reste hors du flow de création d'activité, sauf pour son entrée depuis la landing page.

## Fichiers principaux

- [lib/pages/toolbox_page.dart](/workspaces/presto_app/lib/pages/toolbox_page.dart)
- [lib/pages/toolbox_hub_page.dart](/workspaces/presto_app/lib/pages/toolbox_hub_page.dart)
- [lib/pages/toolbox_je_me_lance_page.dart](/workspaces/presto_app/lib/pages/toolbox_je_me_lance_page.dart)
- [lib/app/secondary_named_routes.dart](/workspaces/presto_app/lib/app/secondary_named_routes.dart)
- [lib/data/je_me_lance_region_contacts.dart](/workspaces/presto_app/lib/data/je_me_lance_region_contacts.dart)

## Cible fonctionnelle

Le flow cible doit respecter ce principe :

1. l'utilisateur ouvre Boîte à outils
2. il choisit Je crée mon activité
3. il arrive sur Je me lance
4. il renseigne région, statut actuel, activité
5. il clique sur Voir mon parcours personnalisé
6. l'application génère un parcours tutoriel
7. l'utilisateur suit les étapes, aides, coûts, contacts et plan 30 jours

## Écran 1 — Boîte à outils

### Objectif

Fournir une landing page simple avec 2 entrées distinctes :

- Je crée mon activité
- Calculer mon prix de vente

### Implémentation attendue

- 1 carte principale création d'activité
- 1 carte secondaire calculatrice
- 1 seule CTA principale sur la carte création
- pas d'ambiguïté entre nouveau parcours et reprise d'un ancien parcours

### Libellés cibles

- titre carte : Je crée mon activité
- bouton principal : Commencer mon parcours
- titre carte calculatrice : Calculer mon prix de vente
- bouton calculatrice : Ouvrir la calculatrice

### Actions techniques

- router la CTA création vers la page Je me lance
- router la CTA calculatrice vers le module pricing
- supprimer ou requalifier les entrées directes vers Mon parcours depuis cette landing si elles brouillent le flow

### Checklist

- [ ] la carte création est visuellement prioritaire
- [ ] le bouton principal ouvre Je me lance
- [ ] aucun bouton secondaire ne concurrence l'action principale
- [ ] la calculatrice reste accessible sans polluer le flow création

## Écran 2 — Je me lance

### Objectif

Collecter uniquement les 3 informations minimales nécessaires pour générer le parcours.

### Données obligatoires

- région
- statut actuel
- activité

### Données explicitement exclues de cet écran

- chiffre d'affaires visé
- clientèle
- dépenses professionnelles
- TVA
- ambition
- association
- modèle économique

### Structure UI attendue

- header orange
- titre : Je me lance
- sous-titre d'aide
- progressbar 0/3 à 3/3
- card principale Commencer votre parcours
- 3 sélecteurs obligatoires
- 1 CTA unique : Voir mon parcours personnalisé

### Comportement de la progressbar

La progression doit être dérivée du nombre de champs obligatoires remplis.

Règle :

- 0 champ rempli = 0/3
- 1 champ rempli = 1/3
- 2 champs remplis = 2/3
- 3 champs remplis = 3/3

Texte dynamique attendu :

- 0/3 renseigné — Commencez par votre région
- 1/3 renseigné — Continuez avec votre statut
- 2/3 renseignés — Il reste votre activité
- 3/3 renseignés — Votre parcours est prêt

### Sélecteur région

#### Règles

- préremplir depuis le profil si disponible
- laisser modifiable
- afficher un état vide si aucune donnée profil
- marquer obligatoire

#### Effets dérivés

- personnalisation des aides
- personnalisation des contacts et guichets
- personnalisation des organismes régionaux
- règles spécifiques DROM

#### Cas DROM

- prioriser les contacts locaux
- afficher les dispositifs ultramarins
- injecter les vigilances liées au territoire

### Sélecteur statut actuel

#### Règles

- utiliser une liste contrôlée de statuts
- marquer obligatoire
- permettre une valeur générique de secours type Autre situation

#### Effets dérivés

- cartes de vigilance personnalisées
- aides conditionnelles selon situation
- contenu pédagogique spécifique au statut

#### Cas métiers minimaux à supporter

- salarié
- fonctionnaire / agent public
- demandeur d'emploi
- étudiant
- retraité
- sans activité
- déjà entrepreneur
- autre situation

### Sélecteur activité

#### Règles

- utiliser un picker ou moteur de recherche simple
- marquer obligatoire
- permettre une valeur Autre activité

#### Effets dérivés

- réglementation métier
- assurances suggérées ou obligatoires
- autorisations ou diplômes possibles
- points de vigilance métier
- démarches spécifiques

#### Cas métiers prioritaires à documenter

- restauration
- BTP / travaux
- coiffure / esthétique
- transport
- service à la personne
- commerce / vente en ligne

### CTA principal

Libellé cible : Voir mon parcours personnalisé

#### Règles d'activation

- désactivé tant que les 3 champs ne sont pas remplis
- activé dès que région + statut + activité sont présents

#### Message d'erreur attendu

Complétez votre région, votre statut et votre activité pour générer votre parcours.

#### Action au clic

- valider les 3 champs
- sauvegarder les réponses utilisateur
- recalculer les données dérivées
- basculer le parcours en état généré
- ouvrir Mon parcours

### Checklist

- [ ] la page ne contient que 3 questions obligatoires
- [ ] la progressbar dépend des champs réellement remplis
- [ ] le bouton principal est unique
- [ ] le bouton reste désactivé tant que 3/3 n'est pas atteint
- [ ] les erreurs de validation sont visibles sans ambiguïté
- [ ] la région profil est bien récupérée si disponible
- [ ] les DROM déclenchent une personnalisation spécifique

## Écran 3 — Mon parcours

### Objectif

Transformer le résultat en tutoriel guidé, pas en simple rapport de synthèse.

### Structure cible

1. Résumé personnalisé
2. Tutoriel réglementation
3. Règles liées au statut actuel
4. Statut juridique conseillé
5. Démarches étape par étape
6. Aides et financements
7. Contacts et guichets utiles
8. Coûts à prévoir
9. Plan d'action 30 jours
10. Suivi de progression

### Header cible

- titre : Mon parcours personnalisé
- sous-titre dynamique basé sur activité + région + statut
- actions : Modifier mes réponses, Recommencer, Continuer mon plan d'action

### Bloc 1 — Résumé personnalisé

#### Données à afficher

- région
- statut actuel
- activité
- niveau de vigilance
- parcours recommandé

#### Attendu technique

- construire un objet summary dédié dans derived
- éviter de recalculer des libellés UI directement dans le widget si le moteur peut les fournir

### Bloc 2 — Tutoriel réglementation

#### Structure minimale

- activité libre ou réglementée
- qualifications ou autorisations éventuelles
- assurances à prévoir
- points de vigilance

#### Attendu technique

- créer un tableau regulationTutorial dans derived
- chaque item doit avoir au moins : type, titre, texte, tone éventuel

### Bloc 3 — Règles liées au statut actuel

#### Attendu technique

- créer un tableau statusWarnings dans derived
- injecter les messages selon le statut choisi

#### Cas minimaux

- fonctionnaire : cumul, autorisation, RH, trace écrite
- salarié : exclusivité, non-concurrence, loyauté, horaires
- demandeur d'emploi : ACRE, ARCE, calendrier, France Travail

### Bloc 4 — Statut juridique conseillé

#### Attendu technique

- créer un objet recommendedLegalStatus dans derived
- y stocker : recommended, justification, planB, disclaimer

#### Contrainte produit

- présenter une orientation
- ne pas présenter cela comme un conseil juridique définitif

### Bloc 5 — Démarches étape par étape

#### Modèle cible

Créer un tableau steps dans derived avec pour chaque étape :

- id
- order
- title
- objective
- todos
- status

#### Étapes minimales

1. vérifier la réglementation
2. vérifier sa situation personnelle
3. choisir le statut de lancement
4. préparer les informations nécessaires
5. déclarer l'activité
6. mettre en place les protections utiles
7. organiser la gestion
8. trouver les premières aides
9. lancer les premières offres

#### Statuts à supporter

- todo
- doing
- done

### Bloc 6 — Aides et financements

#### Modèle cible

Chaque aide doit pouvoir exposer :

- nom
- pourQui
- intérêt
- vigilance
- action
- relevant
- status

#### Règles de filtrage

- filtrer par région
- filtrer par statut actuel
- filtrer par activité si utile
- prioriser les dispositifs DROM si la région est ultramarine

### Bloc 7 — Contacts et guichets utiles

#### Modèle cible

Chaque contact doit exposer :

- nom
- type
- description
- url ou moyen de contact
- priorité

#### Règles

- si région connue, charger les contacts de cette région
- si DROM, remonter en premier les contacts locaux

### Bloc 8 — Coûts à prévoir

#### Modèle cible

Chaque coût doit exposer :

- label
- obligation : required ou recommended
- min
- max
- note

#### Catégories minimales

- formalités
- assurance professionnelle
- compte bancaire
- comptable
- matériel
- communication
- outils numériques
- frais métier spécifiques

### Bloc 9 — Plan d'action 30 jours

#### Modèle cible

Le plan30 doit être structuré par semaine, puis par action.

#### Semaine 1

- réglementation
- statut actuel
- assurances
- aides possibles
- documents nécessaires

#### Semaine 2

- choix du statut de lancement
- préparation de la déclaration
- demandes d'autorisation
- contact organismes
- préparation de l'offre

#### Semaine 3

- déclaration
- assurance
- devis et facture
- suivi des charges
- supports de communication

#### Semaine 4

- publication des offres
- test du prix
- premiers clients
- ajustements
- suivi des premiers résultats

### Bloc 10 — Suivi de progression

#### Données à stocker

- completedSteps
- currentStep
- percent

#### Affichage cible

- nombre d'étapes terminées
- nombre d'étapes restantes
- pourcentage global

### Checklist

- [ ] Mon parcours s'affiche comme un tutoriel ordonné
- [ ] chaque bloc correspond à une question utilisateur claire
- [ ] les statuts d'étapes sont persistés
- [ ] les aides sont filtrées selon le contexte
- [ ] les contacts sont régionalisés
- [ ] les DROM ont des contenus dédiés
- [ ] le plan 30 jours est actionnable

## Données et persistance

### Document Firestore cible

Chemin : users/{uid}/parcours/{parcoursId}

### Structure recommandée

```json
{
  "status": "generated",
  "step": "parcours",
  "updatedAt": "timestamp",
  "data": {
    "region": "Guadeloupe",
    "currentStatus": "Salarié",
    "selectedActivity": "Jardinage",
    "projectText": "",
    "territory": {
      "region": "Guadeloupe",
      "departement": "",
      "commune": ""
    }
  },
  "derived": {
    "summary": {},
    "regulationTutorial": [],
    "statusWarnings": [],
    "recommendedLegalStatus": {},
    "steps": [],
    "aides": [],
    "costs": [],
    "contacts": [],
    "plan30": []
  },
  "progress": {
    "completedSteps": [],
    "currentStep": 1,
    "percent": 0
  }
}
```

### États de parcours à supporter

- draft
- generated
- in_progress
- completed

### Règles de reprise

- si Firestore est disponible, reprendre le dernier parcours
- si Firestore est indisponible, rester en mode local
- si un parcours existe déjà, distinguer clairement reprise et nouveau parcours

## Mode local et résilience

### Règles

- le flow reste utilisable hors persistance distante
- les 3 choix peuvent être saisis localement
- le parcours peut être généré localement
- un message explicite doit signaler la limite de reprise multi-appareils

### Message recommandé

Votre parcours est disponible sur cet appareil. Connectez-vous pour le sauvegarder et le retrouver plus tard.

## Règles UX obligatoires

### 1. Ne pas ouvrir Mon parcours sans les 3 choix

- pas d'accès direct ambigu à un ancien parcours depuis la landing page principale
- si ancien parcours existant, proposer explicitement Continuer mon dernier parcours ou Créer un nouveau parcours

### 2. Une seule action principale par écran

- sur Je me lance, la CTA principale unique doit être Voir mon parcours personnalisé

### 3. Ne pas surcharger la première étape

- aucune question avancée sur CA, TVA, ambition, clientèle, dépenses, modèle économique à ce stade

### 4. Afficher Mon parcours comme un tutoriel

- chaque bloc doit répondre à une question concrète
- éviter l'effet rapport ou audit froid

## Checklist d'implémentation par fichier

### [lib/pages/toolbox_page.dart](/workspaces/presto_app/lib/pages/toolbox_page.dart)

- [ ] renommer les libellés selon la spec cible
- [ ] garder 2 cartes maximum
- [ ] rendre la CTA création dominante
- [ ] éviter toute entrée directe confuse vers un ancien parcours

### [lib/pages/toolbox_hub_page.dart](/workspaces/presto_app/lib/pages/toolbox_hub_page.dart)

- [ ] vérifier la cohérence des wrappers de navigation
- [ ] garantir une redirection claire vers Je me lance et Mon parcours

### [lib/pages/toolbox_je_me_lance_page.dart](/workspaces/presto_app/lib/pages/toolbox_je_me_lance_page.dart)

- [ ] implémenter Je me lance avec 3 champs obligatoires uniquement
- [ ] brancher la progressbar 0/3 à 3/3
- [ ] unifier la validation via une seule CTA
- [ ] générer un objet derived plus structuré
- [ ] transformer Mon parcours en tutoriel séquencé
- [ ] persister progression et statuts d'étapes

### [lib/app/secondary_named_routes.dart](/workspaces/presto_app/lib/app/secondary_named_routes.dart)

- [ ] stabiliser les routes toolbox
- [ ] aligner les routes avec la nomenclature cible si nécessaire

## Routes recommandées

- /toolbox
- /toolbox/je-me-lance
- /toolbox/mon-parcours
- /toolbox/calculatrice-prix

## Ordre recommandé d'implémentation

1. simplifier la landing page Boîte à outils
2. verrouiller la page Je me lance autour des 3 choix
3. brancher progressbar et CTA unique
4. restructurer le modèle derived
5. transformer Mon parcours en tutoriel ordonné
6. ajouter suivi de progression
7. affiner les cas DROM, statuts et activités réglementées
8. stabiliser persistance et reprise

## Définition de terminé

Le flow pourra être considéré comme conforme quand :

- l'utilisateur comprend immédiatement qu'il doit commencer par Je crée mon activité
- Je me lance ne demande que région, statut, activité
- Mon parcours ne s'ouvre jamais sans ces 3 choix
- Mon parcours s'affiche comme un guide pas à pas
- les aides, contacts, coûts et plan 30 jours sont contextualisés
- la progression utilisateur est suivie et persistée