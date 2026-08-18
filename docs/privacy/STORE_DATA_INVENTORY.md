# Inventaire des données Store — iliprestō

Révision : **2026-08-18**

Objectif : conserver une matrice unique entre le code, Google Play Data Safety, Apple App Privacy et la politique publique.

| Donnée | Collectée | Partagée avec tiers | Temporaire seulement | Liée à l’identité | Finalité | Systèmes principaux |
|---|---:|---:|---:|---:|---|---|
| E-mail | Oui | Fournisseur d’auth / Firebase selon parcours | Non | Oui | compte, authentification, support | Firebase Auth, Firestore |
| Téléphone | Oui si renseigné/vérifié | Firebase/outil de vérification selon parcours | Non | Oui | compte, sécurité, mise en relation | Firebase Auth/Firestore |
| Nom / pseudo | Oui | Fournisseur social/Firebase selon parcours | Non | Oui | profil, compte | Firebase Auth/Firestore |
| UID Firebase | Oui | Firebase | Non | Oui | compte, sécurité, relations de données | Firebase Auth/Firestore |
| SIRET | Oui pour parcours pro | service de vérification + backend | Non | Oui | vérification professionnelle / antifraude | Cloud Functions, Firestore |
| Ville / code postal | Oui si renseigné | Firebase ; visible selon contenu publié | Non | Oui pour profil/annonce | recherche locale, affichage | Firestore |
| Localisation approx. issue IP | Oui selon SDK | Google Ads/Firebase selon SDK | Selon prestataire | Peut être liée à appareil | publicité, sécurité, analytics | AdMob, Firebase |
| Photo de profil | Oui si fournie | Firebase Storage | Non | Oui | profil | Storage/Firestore |
| Photos d’annonce | Oui si fournies | Firebase Storage ; visibles avec l’annonce | Non | Oui à l’auteur | contenu annonce | Storage/Firestore |
| Vidéos | Selon fonction active | Firebase Storage | Non | Oui à l’auteur | contenu | Storage |
| Audio / voix | Oui si fonction utilisée | Firebase/IA selon action | Selon fonction | Oui | messagerie ou assistance IA | Storage/Functions/Firebase AI |
| Messages | Oui | Firebase | Non | Oui | messagerie, modération, sécurité | Firestore/Functions |
| Pièces jointes / documents | Oui si envoyés | Firebase Storage | Non | Oui | annonce/messagerie | Storage |
| Annonces | Oui | Firebase ; publication aux autres utilisateurs | Non | Oui à l’auteur | marketplace | Firestore |
| Avis | Oui | Firebase ; visibles selon règles produit | Non | Oui | réputation / retour utilisateur | Firestore |
| Recherches / interactions | Oui selon fonction et analytics | Firebase Analytics/Google selon consentement | Non ou agrégé selon outil | Potentiellement | fonction, analytics | Firestore/Analytics |
| Adresse IP | Oui automatiquement selon services | Google/Firebase/Ads | Selon prestataire | Potentiellement | sécurité, fraude, localisation approximative, ads | Firebase, AdMob |
| Appareil / OS / version app | Oui | Firebase/Google Ads | Non ou agrégé | Potentiellement | diagnostic, sécurité, publicité | Crashlytics, Performance, Ads |
| Crash logs | Oui | Firebase Crashlytics | Non | Potentiellement | diagnostic | Crashlytics |
| Données performance | Oui | Firebase Performance et Ads selon SDK | Non | Potentiellement | performance/analytics/ads | Performance, AdMob |
| Jeton FCM | Oui | Firebase | Non | Oui au device/installation | notifications | FCM |
| App Check / Play Integrity / reCAPTCHA | Oui | Google/Firebase | Souvent courte durée pour jeton, journaux selon service | Potentiellement | sécurité, intégrité, antifraude | App Check, Play Integrity, reCAPTCHA |
| Identifiant publicitaire / Device ID | Oui lorsque disponible et autorisé | Google Mobile Ads | Non | À l’appareil | publicité et mesure | AdMob |
| Advertising Data | Oui lorsque Ads actif | Google Mobile Ads | Non | Potentiellement | publicité / mesure | AdMob |
| Consentement analytics/marketing | Oui localement | Google Consent Mode/UMP selon fonction | Non | À l’installation | preuve opérationnelle du choix, pilotage SDK | SharedPreferences, UMP |
| Contenus envoyés à l’IA | Oui uniquement si fonction déclenchée | Firebase AI/Google | Selon service/configuration | Oui si contenu du compte | génération demandée | Firebase AI |

## Règles de maintenance

1. Toute nouvelle dépendance réseau doit être ajoutée ici avant merge.
2. Toute nouvelle permission Android/iOS doit déclencher une revue Data Safety/App Privacy.
3. Toute nouvelle donnée Firestore/Storage doit être classée : finalité, durée, visibilité et base légale.
4. Toute nouvelle fonction IA doit décrire exactement ce qui quitte l’appareil.
5. Tout changement AdMob/mediation/IDFA doit déclencher une nouvelle revue Apple Tracking.
6. Les déclarations Store doivent être comparées à ce fichier avant chaque release candidate.
