# Scope actuel - Sans paiement en ligne / Sans abonnement Pro

## Fonctions exclues pour l'instant

- Paiement intégré
- Commission plateforme
- Abonnement Pro
- Gestion de facturation
- Stripe / paiement en ligne

Ces fonctions seront traitées plus tard.

---

# Fonctions prioritaires actuelles

## 1. Vérification SIRET

Objectif :
Permettre à un prestataire professionnel de renseigner son SIRET et d'obtenir un statut de vérification.

Statuts possibles :
- non_renseigne
- en_attente
- valide
- invalide
- a_revoir

Données :
- SIRET
- Nom entreprise
- Activité
- Commune
- Département
- Région
- Date de vérification
- Source de vérification
- Statut

---

## 2. Notation complète prestataire / client

Objectif :
Créer une vraie réputation marketplace.

Notation prestataire :
- Qualité du travail
- Ponctualité
- Communication
- Respect du budget
- Professionnalisme

Notation client :
- Clarté de la demande
- Communication
- Respect du rendez-vous
- Sérieux

Résultat :
- Note moyenne
- Nombre d'avis
- Score de confiance
- Badges éventuels

---

## 3. Fiche Pro enrichie

Objectif :
Donner plus de crédibilité aux prestataires.

Contenu fiche :
- Nom commercial
- Photo ou logo
- Région
- Département
- Ville
- Catégories de services
- Description longue
- Expérience
- SIRET
- Statut de vérification
- Photos réalisations
- Zone d'intervention
- Disponibilités
- Note moyenne
- Nombre d'avis
- Badges confiance
- Liens utiles

---

## 4. Parcours création entreprise

Objectif :
Aider un utilisateur à créer ou structurer son activité selon sa région.

Exemple :
Créer son food truck en Guadeloupe.

Le parcours doit dépendre :
- De la région du profil utilisateur
- Du département
- Du type de projet
- Du statut souhaité
- De l'activité

---

## 5. Fiche projet personnalisée

Objectif :
Créer une fiche projet claire avec les étapes, organismes et aides possibles.

Contenu :
- Résumé du projet
- Étapes administratives
- Statut conseillé
- Organismes utiles
- CCI
- CMA si activité artisanale
- Région
- France Travail
- France Services
- Aides publiques possibles
- Checklist
- Budget de départ estimatif
- Documents à préparer

---

## 6. Infos CCI / Région / aides publiques selon la région du profil

Principe :
La région enregistrée dans le profil utilisateur détermine les organismes et aides affichées.

Exemple :
Si profil.region = "Guadeloupe", alors afficher les ressources Guadeloupe.

Collections Firestore proposées :
- users
- professional_profiles
- siret_verifications
- reviews
- review_summaries
- business_regions
- business_project_templates
- business_project_sheets
- local_organizations
- public_aids
