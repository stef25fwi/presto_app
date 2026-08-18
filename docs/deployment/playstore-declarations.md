# Google Play — Data Safety et déclarations confidentialité

Dernière révision : **18 août 2026**  
Application : **iliprestō**  
Package Android : `fr.ilipresto.app`

Ce document est la source de saisie pour la section **Sécurité des données / Data Safety** de Google Play. Il doit être relu à chaque changement de SDK, de finalité ou de configuration publicitaire.

Références internes :

- `docs/privacy/STORE_DATA_INVENTORY.md`
- `docs/privacy/PROCESSOR_REGISTER.md`
- `docs/deployment/appstore-privacy-declarations.md`
- politique publique : `https://ilipresto.fr/confidentialite`
- suppression de compte : `https://ilipresto.fr/suppression-compte`

## 1. Réponses globales Data Safety

| Question Play Console | Réponse iliprestō | Justification |
|---|---|---|
| L’application collecte-t-elle ou partage-t-elle des données utilisateur ? | **Oui** | compte, contenus, sécurité, analytics et publicité |
| Les données sont-elles chiffrées en transit ? | **Oui** | trafic applicatif vers Firebase/Google et autres services via HTTPS/TLS |
| L’utilisateur peut-il demander la suppression de ses données ? | **Oui** | suppression depuis l’app + page publique `/suppression-compte` |
| Politique de confidentialité publique ? | **Oui** | `/confidentialite`, page statique sans authentification |
| L’application contient-elle de la publicité ? | **Oui** | Google Mobile Ads / AdMob lorsque le consentement applicable l’autorise |
| Publicité demandée avant consentement UMP ? | **Non** | `AdsConsentService` exige `ConsentInformation.canRequestAds()` avant initialisation/requête |
| Application destinée aux enfants ? | **Non** | positionnement grand public / mise en relation et messagerie ; ne pas sélectionner Families sans nouvelle revue |

## 2. Matrice de données à déclarer

La colonne **Partagé** suit la définition Google Play. Les traitements réalisés pour le compte d’iliprestō par un prestataire peuvent relever de l’exception « service provider » ; les données utilisées par un réseau publicitaire pour ses propres finalités publicitaires doivent être déclarées comme partagées lorsque la définition Play l’exige.

| Catégorie Play | Type de donnée | Collectée | Partagée | Obligatoire ? | Finalités à sélectionner |
|---|---|---:|---:|---|---|
| Informations personnelles | Nom / pseudonyme | Oui | Non* | Compte : oui ; nom réel : facultatif | Fonctionnement de l’app, gestion du compte |
| Informations personnelles | Adresse e-mail | Oui | Non* | Oui pour compte e-mail ; fournisseur social selon choix | Fonctionnement de l’app, gestion du compte, sécurité |
| Informations personnelles | Numéro de téléphone | Oui | Non* | Facultatif selon parcours | Fonctionnement de l’app, gestion du compte, prévention de la fraude |
| Informations personnelles | Autres informations personnelles | Oui | Non* | Facultatif | **SIRET** et informations professionnelles, fonctionnement, prévention de la fraude |
| Localisation | Localisation approximative | Oui | Oui via publicité lorsque applicable | Facultatif | Fonctionnement (ville/CP), publicité, analytics, sécurité selon SDK |
| Photos et vidéos | Photos | Oui | Non* | Facultatif | Fonctionnement de l’app, contenu utilisateur, modération |
| Photos et vidéos | Vidéos | Selon fonction active | Non* | Facultatif | Fonctionnement de l’app |
| Fichiers audio | Voix / notes audio | Oui | Non* | Facultatif | Fonctionnement de l’app, messagerie, fonctions IA si déclenchées |
| Fichiers et documents | Fichiers / documents | Oui | Non* | Facultatif | Fonctionnement de l’app, annonces, messagerie |
| Messages | Messages dans l’application | Oui | Non* | Fonction de messagerie | Fonctionnement de l’app, sécurité, modération |
| Activité dans l’app | Interactions avec l’app | Oui si consentement requis obtenu | Oui via SDK publicitaire lorsque applicable | Facultatif | Analytics, fonctionnement, publicité |
| Activité dans l’app | Recherches dans l’application | Oui | Non* | Facultatif | Fonctionnement de l’app, analytics si activé |
| Activité dans l’app | Autre contenu généré par l’utilisateur | Oui | Non* | Selon usage | Annonces, avis et contenus soumis à l’IA : fonctionnement/modération |
| Informations et performances de l’app | Journaux de plantage | Oui | Oui/exception prestataire selon qualification Play | Automatique Crashlytics | Analytics/diagnostic, fonctionnement |
| Informations et performances de l’app | Diagnostics | Oui | Oui/exception prestataire selon qualification Play | Automatique selon SDK | Diagnostic, sécurité, fonctionnement |
| Informations et performances de l’app | Autres données de performance | Oui | Oui/exception prestataire selon qualification Play | Automatique Firebase Performance/Ads | Analytics/diagnostic, publicité selon SDK |
| Identifiants de l’appareil ou autres | Identifiant utilisateur | Oui | Non* | Oui | Fonctionnement, compte, sécurité, analytics selon consentement |
| Identifiants de l’appareil ou autres | Identifiant d’appareil / installation | Oui | Oui via SDK publicitaire lorsque applicable | Automatique selon SDK | Analytics, publicité, prévention de la fraude |
| Identifiants de l’appareil ou autres | Identifiant publicitaire Android | Oui lorsque disponible/autorisé | Oui | Facultatif / SDK Ads | Publicité, analytics publicitaire, prévention de la fraude |

`*` : les transferts à Firebase/Google agissant comme prestataire doivent être qualifiés au regard de la définition Play et des conditions contractuelles en vigueur. Ils ne doivent pas être automatiquement assimilés à du « partage » si l’exception service provider s’applique. En revanche, les usages propres à la publicité tierce ne doivent pas être masqués par cette exception.

## 3. SDK et données à intégrer dans la déclaration

### Firebase Authentication / connexions sociales

À couvrir : e-mail, téléphone, nom/pseudonyme, UID Firebase, fournisseur de connexion, adresse IP et informations techniques nécessaires à l’authentification et à la sécurité. Les connexions Google, Facebook et Apple transmettent également les éléments autorisés par l’utilisateur à ces fournisseurs.

### Firestore / Storage / Functions / Messaging

À couvrir : profil, annonces, messages, avis, pièces jointes, photos, documents, audio, jetons de notification et métadonnées techniques nécessaires au fonctionnement.

### Firebase Analytics

Collecte activée uniquement selon les choix applicables enregistrés par `CookieConsentService`. Déclarer les interactions, identifiants techniques et usages d’analytics effectivement envoyés lorsque la collecte est activée.

### Crashlytics et Performance

Déclarer journaux de crash, diagnostics, métadonnées d’appareil et performances conformément aux disclosures Firebase correspondant aux versions embarquées.

### Firebase App Check / reCAPTCHA Enterprise / Play Integrity

Déclarer les identifiants et signaux techniques de sécurité/intégrité transmis pour prévenir les abus et protéger les services backend. Ces données ne servent pas à « approuver » un utilisateur.

### Firebase AI

Les textes, images, audio ou autres contenus qu’un utilisateur soumet volontairement à une fonction IA peuvent être transmis à Google/Firebase afin de produire la réponse demandée. Ces contenus restent classés selon leur nature (texte/contenu utilisateur, photo, audio) et leur finalité principale est le fonctionnement de l’app.

### Google Mobile Ads / AdMob + UMP

À couvrir au minimum selon la configuration active et les disclosures Google :

- adresse IP et localisation approximative susceptible d’en être déduite ;
- identifiant d’appareil / identifiant publicitaire disponible ;
- interactions publicitaires et données publicitaires ;
- diagnostics, crashs et performances du SDK ;
- interactions produit utilisées pour la publicité et la mesure.

Le code iliprestō impose deux verrous :

1. consentement marketing applicatif ;
2. `ConsentInformation.canRequestAds() == true` côté Google UMP.

Aucune bannière AdMob ne doit être chargée si l’un de ces verrous échoue.

## 4. Permissions Android sensibles

| Permission / capacité | Usage | Exigence |
|---|---|---|
| `CAMERA` | photo d’annonce / profil | demande contextuelle et explication claire |
| `RECORD_AUDIO` | note vocale / fonction vocale | demande contextuelle et explication claire |
| `POST_NOTIFICATIONS` | notifications | demande runtime |
| `AD_ID` | publicité Google lorsque disponible | déclaration Data Safety et conformité Ads |
| Localisation appareil | **Non demandée pour le parcours de base** | conserver l’absence de permission GPS tant qu’elle n’est pas nécessaire |
| Contacts / SMS | **Non demandés** | ne pas ajouter sans nouvelle revue privacy |

## 5. URLs à saisir dans Play Console

- Politique de confidentialité : `https://ilipresto.fr/confidentialite`
- Suppression de compte : `https://ilipresto.fr/suppression-compte`
- CGU : `https://ilipresto.fr/cgu`
- Mentions légales : `https://ilipresto.fr/mentions-legales`

Les deux premières disposent désormais d’une représentation Web statique, afin de rester lisibles sans connexion au compte et indépendamment du mode pré-lancement Flutter.

## 6. Contrôle avant soumission

Avant de cliquer sur **Enregistrer / Envoyer** dans Play Console :

- générer l’AAB de release réellement destiné au Store ;
- vérifier les SDK effectivement présents dans l’artefact final ;
- relire les disclosures des versions exactes de Firebase et Google Mobile Ads ;
- tester `/confidentialite` et `/suppression-compte` depuis un navigateur privé non authentifié ;
- comparer ligne à ligne la matrice ci-dessus avec la politique publique ;
- ne déclarer aucune donnée comme « non collectée » si un SDK de l’artefact la transmet ;
- archiver une capture/PDF de la déclaration Play finale avec le numéro de version soumis.

## 7. État

**Code et documentation : prêts pour saisie Store après CI verte.**  
**Action externe obligatoire :** la déclaration finale doit être saisie et validée dans Play Console par le titulaire du compte développeur. Toute modification future de SDK, publicité, IA ou finalité impose une nouvelle revue de ce fichier.
