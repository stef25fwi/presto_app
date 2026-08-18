# Apple App Store Connect — App Privacy iliprestō

Dernière révision : **18 août 2026**  
Bundle iOS : `fr.ilipresto.app`

Ce fichier sert de source de vérité pour la fiche **App Privacy** dans App Store Connect. Les réponses doivent couvrir iliprestō **et tous les partenaires/SDK intégrés**.

Politique publique : `https://ilipresto.fr/confidentialite`

## 1. Données à déclarer

| Apple Data Type | Collectée | Liée à l’utilisateur | Tracking | Finalités principales |
|---|---:|---:|---:|---|
| Contact Info → Name | Oui | Oui | Non | App Functionality, Account Management |
| Contact Info → Email Address | Oui | Oui | Non | App Functionality, Account Management, Security |
| Contact Info → Phone Number | Oui | Oui | Non | App Functionality, Account Management, Security |
| Location → Coarse Location | Oui | Selon source | Oui lorsque utilisée par publicité personnalisée/mesure tierce | App Functionality, Third-Party Advertising, Analytics |
| User Content → Photos or Videos | Oui | Oui | Non | App Functionality, Moderation |
| User Content → Audio Data | Oui | Oui | Non | App Functionality, Messaging, AI feature when requested |
| User Content → Customer Support | Oui | Oui | Non | App Functionality |
| User Content → Other User Content | Oui | Oui | Non | Annonces, messages, avis, documents, contenus soumis aux fonctions IA |
| Identifiers → User ID | Oui | Oui | Non | App Functionality, Account Management, Security, Analytics when enabled |
| Identifiers → Device ID | Oui | Selon SDK | **Oui** lorsque Google Mobile Ads l’utilise pour le tracking autorisé | Third-Party Advertising, Analytics, Security |
| Usage Data → Product Interaction | Oui | Selon SDK | Oui lorsque utilisé pour publicité/mesure tierce | Analytics, Third-Party Advertising |
| Usage Data → Advertising Data | Oui si Ads actif | Selon SDK | Oui lorsque utilisé pour tracking publicitaire | Third-Party Advertising, Analytics |
| Diagnostics → Crash Data | Oui | Généralement non ou pseudonyme selon SDK/config | Non | App Functionality, Analytics |
| Diagnostics → Performance Data | Oui | Peut être liée par certains SDK | Non | App Functionality, Analytics, Third-Party Advertising selon Google Mobile Ads |
| Diagnostics → Other Diagnostic Data | Oui | Selon SDK | Non | Security, App Functionality |
| Other Data | Oui | Oui | Non | SIRET/informations professionnelles, sécurité et vérification |

## 2. Fournisseurs à prendre en compte

### Firebase / Google

- Firebase Authentication
- Cloud Firestore
- Cloud Functions
- Firebase Storage
- Firebase Cloud Messaging
- Firebase Remote Config
- Firebase Analytics
- Firebase Crashlytics
- Firebase Performance Monitoring
- Firebase App Check
- Firebase AI
- reCAPTCHA Enterprise / signaux d’intégrité associés

### Authentification sociale

- Google Sign-In
- Facebook Login via Firebase Authentication
- Sign in with Apple

Les informations demandées aux fournisseurs sociaux sont limitées à celles nécessaires à l’authentification et au profil, notamment e-mail, identité/profil autorisé et identifiant fournisseur.

### Google Mobile Ads / AdMob + UMP

Selon les disclosures Google, le SDK peut collecter notamment :

- adresse IP, pouvant permettre d’estimer une localisation générale ;
- crash logs et diagnostics ;
- performance liée à l’utilisateur ;
- Device ID, y compris identifiant publicitaire lorsqu’il est disponible ;
- Advertising Data ;
- Product Interaction.

Ces données doivent être reflétées dans App Privacy même si elles proviennent d’un SDK tiers.

## 3. App Tracking Transparency

`ios/Runner/Info.plist` contient `NSUserTrackingUsageDescription`.

Politique de soumission :

1. aucune requête AdMob n’est effectuée avant que Google UMP indique `canRequestAds() == true` ;
2. le message IDFA/ATT doit être configuré dans **AdMob → Privacy & messaging** avant la soumission iOS si le mode publicitaire choisi peut utiliser l’IDFA ;
3. si l’utilisateur refuse ATT, l’application doit continuer à fonctionner et Google Mobile Ads ne doit pas disposer de l’IDFA ;
4. App Store Connect doit déclarer le tracking pour les données susceptibles d’être utilisées à cette fin par le SDK lorsque l’utilisateur l’autorise ;
5. si iliprestō décide ultérieurement d’exclure totalement le tracking, la configuration Ads et la fiche App Privacy doivent être mises à jour ensemble.

## 4. Privacy manifests Apple

Le build final doit être contrôlé avec le rapport de confidentialité généré par Xcode/Organizer :

- vérifier la présence des manifests des SDK concernés ;
- Google Mobile Ads SDK moderne fournit un privacy manifest ;
- Firebase et les plugins iOS doivent être vérifiés dans les versions réellement résolues par CocoaPods ;
- ne pas se fier uniquement à `pubspec.yaml` : la certification porte sur l’archive iOS finale.

Un `PrivacyInfo.xcprivacy` applicatif ne doit être ajouté que pour les collectes ou Required Reason APIs propres à l’application qui ne sont pas déjà décrites par les composants concernés. Éviter un manifeste générique ou inexact uniquement pour « faire disparaître » un avertissement.

## 5. Finalités Apple à utiliser

- **App Functionality** : authentification, compte, annonces, messagerie, avis, notifications, sécurité, support, IA demandée par l’utilisateur.
- **Analytics** : Firebase Analytics, Crashlytics/Performance lorsque la classification Apple correspond, mesure produit et publicitaire.
- **Third-Party Advertising** : Google Mobile Ads / AdMob.
- **Product Personalization** : sélectionner uniquement si une donnée est réellement utilisée pour personnaliser l’expérience iliprestō ; ne pas l’utiliser par défaut.
- **Developer’s Advertising or Marketing** : sélectionner uniquement si iliprestō utilise directement la donnée pour son propre marketing.
- **Other Purposes** : uniquement lorsqu’aucune finalité Apple plus précise ne convient.

## 6. Vérifications avant soumission

- URL `https://ilipresto.fr/confidentialite` accessible sans compte ;
- politique identique sur les traitements essentiels décrits dans App Store Connect ;
- page suppression de compte accessible ;
- version exacte de Google Mobile Ads et Firebase vérifiée dans l’archive ;
- message GDPR UMP publié dans AdMob pour les zones concernées ;
- message IDFA publié dans AdMob si tracking/IDFA utilisé ;
- test iOS neuf : consentement accepté ;
- test iOS neuf : consentement refusé ;
- test ATT refusé : aucune perte de fonction essentielle ;
- test ATT accepté : publicité fonctionne selon la configuration autorisée ;
- rapport Privacy Manifest de l’archive contrôlé ;
- capture de la fiche App Privacy finale archivée avec le numéro de build soumis.

## 7. État

**Référentiel de saisie App Privacy : prêt après CI verte et validation de l’archive iOS.**  
**Actions externes obligatoires :** configuration des messages UMP/IDFA dans AdMob et saisie finale dans App Store Connect par le titulaire du compte développeur.
