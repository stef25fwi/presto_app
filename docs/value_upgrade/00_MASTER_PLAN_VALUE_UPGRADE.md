# Plan d'upgrade valeur - iliprestō / Prestō

Objectif : ajouter les fonctions qui augmentent fortement la valeur du projet.

## Ordre de priorité recommandé

| Priorité | Fonction | Impact valeur | Objectif produit |
|---|---|---|---|
| 1 | Paiement intégré / commission | Très fort | Monétisation directe sur chaque job |
| 2 | Abonnement pro | Très fort | Revenus récurrents |
| 3 | Vérification identité / KYC | Fort | Confiance + sécurité plateforme |
| 4 | Notation complète prestataire/client | Fort | Qualité marketplace |
| 5 | Push notifications solides | Moyen à fort | Engagement + rapidité |
| 6 | Admin modération complet | Fort | Contrôle qualité + conformité |
| 7 | Parcours création entreprise par région/département | Très fort | Différenciation forte |
| 8 | Fiches projet CCI / Région / aides publiques | Très différenciant | Accompagnement unique |
| 9 | Application Android publiée | Fort | Crédibilité + acquisition |
| 10 | Application iOS publiée | Très fort | Crédibilité premium |
| 11 | Partenariats locaux | Très fort | Traction locale + confiance |

---

# 1. Paiement intégré / commission

## Objectif
Permettre à un client de payer une prestation depuis l'application.
La plateforme prélève une commission.

## Modèle recommandé
- Stripe Connect Express
- PaymentIntent
- Capture manuelle possible
- Commission plateforme via application_fee_amount
- Paiement libéré au prestataire après validation

## À créer
- Service paiement Flutter
- Cloud Functions paiement
- Statuts transaction
- Historique paiements
- Reçus
- Gestion litige simple

## Collections Firestore proposées
- payments
- payment_intents
- provider_payouts
- platform_fees

---

# 2. Abonnement pro

## Objectif
Permettre aux prestataires de payer un abonnement pour plus de visibilité.

## Offres proposées
- Gratuit
- Pro
- Pro Plus
- Partenaire local

## Fonctions
- Badge Pro
- Mise en avant annonces
- Plus de réponses possibles
- Statistiques profil
- Priorité dans les résultats

## Collections
- subscriptions
- pro_profiles
- billing_events

---

# 3. Vérification identité / KYC

## Objectif
Renforcer la confiance.

## Niveaux
- Email vérifié
- Téléphone vérifié
- Identité vérifiée
- SIRET vérifié pour professionnel
- Badge prestataire vérifié

## Collections
- identity_checks
- kyc_requests
- trusted_profiles

---

# 4. Notation complète prestataire/client

## Objectif
Créer une vraie marketplace de confiance.

## Critères prestataire
- Communication
- Ponctualité
- Qualité du travail
- Respect du budget
- Professionnalisme

## Critères client
- Clarté de la demande
- Respect du rendez-vous
- Paiement / sérieux
- Communication

## Collections
- reviews
- review_summaries
- reputation_scores

---

# 5. Push notifications solides

## Objectif
Notifier rapidement les utilisateurs.

## Notifications prioritaires
- Nouvelle offre proche
- Message reçu
- Offre acceptée
- Paiement reçu
- Paiement validé
- Avis reçu
- Document KYC validé
- Annonce refusée ou validée

## Collections
- notification_tokens
- notifications
- notification_preferences

---

# 6. Admin modération complet

## Objectif
Avoir un vrai back-office.

## Modules admin
- Validation annonces
- Modération photos
- Modération textes
- Gestion utilisateurs
- Gestion signalements
- Gestion litiges
- Gestion paiements
- Gestion badges Pro
- Statistiques globales

## Collections
- admin_actions
- moderation_queue
- reports
- disputes

---

# 7. Parcours création entreprise par région/département

## Objectif
Accompagner chaque utilisateur selon sa localisation et son projet.

## Exemple
Créer son food truck en Guadeloupe.

## Données à prévoir
- Région
- Département
- Ville
- Type de projet
- Statut recommandé
- Organismes utiles
- Étapes administratives
- Aides possibles
- Contacts CCI / CMA / Région / collectivités

## Collections
- business_paths
- business_steps
- local_organizations
- public_aids

---

# 8. Fiches projet CCI / Région / aides publiques

## Objectif
Créer des fiches ultra personnalisées.

## Exemple de fiche
- Créer un food truck en Guadeloupe
- Créer une activité de jardinage en Martinique
- Créer une activité de livraison en Guyane
- Créer une activité d'aide à domicile à La Réunion

## Contenu fiche
- Résumé du projet
- Démarches
- Statuts possibles
- Autorisations
- Organismes
- Numéros
- Emails
- Liens utiles
- Aides publiques
- Budget de départ
- Checklist

## Collections
- project_sheets
- project_sheet_templates
- regional_contacts
- aid_programs

---

# 9. Application Android publiée

## Objectif
Publier sur Google Play.

## À vérifier
- package id final
- signature upload-keystore
- politique confidentialité
- captures écran
- icône
- fiche Play Store
- App Bundle AAB
- tests internes

---

# 10. Application iOS publiée

## Objectif
Publier sur App Store.

## À vérifier
- Bundle ID
- Apple Developer Account
- certificat
- provisioning profile
- icône iOS
- screenshots
- privacy nutrition labels
- TestFlight
- validation App Store

Note : la compilation iOS finale nécessite macOS + Xcode.

---

# 11. Partenariats locaux

## Objectif
Augmenter la crédibilité et l'ancrage local.

## Partenaires cibles
- CCI
- CMA
- Région
- Communes
- Associations d'entrepreneurs
- Espaces France Services
- Missions locales
- Boutiques de gestion
- Experts-comptables
- Banques locales

## Collections
- partners
- partner_contacts
- partner_offers
- local_campaigns

