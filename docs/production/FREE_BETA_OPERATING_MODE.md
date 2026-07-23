# Mode d’exploitation Ilipresto — bêta gratuite / version payante

## Objectif

Ilipresto démarre en **bêta gratuite**. Aucun abonnement, paiement, renouvellement ou commission n’est activé. Le passage à la version payante est ensuite réalisé depuis un toggle unique dans l’administration, uniquement lorsque les informations juridiques commerciales sont complètes.

## Source de vérité

Deux documents Firestore privés sont utilisés :

- `app_config/legal` : mode d’exploitation, versions juridiques, date d’entrée en vigueur et identité de l’éditeur ;
- `app_config/subscriptions` : miroir opérationnel utilisé par l’interface et les fonctions de paiement.

Les visiteurs non connectés ne lisent pas directement ces documents. La Cloud Function en lecture seule `getPublicLegalConfig` lit `app_config/legal` avec l’Admin SDK, retire tout champ interne et retourne uniquement les informations destinées aux mentions légales.

Le mode canonique est :

- `free_beta` : accès gratuit, Stripe désactivé, section abonnements masquée, droits gratuits actifs ;
- `commercial` : section abonnements et Stripe activés, droits définis par les formules.

Les anciens champs restent présents pour compatibilité, mais ils sont neutralisés lorsqu’ils contredisent `free_beta`.

## Mise en service initiale

1. Ouvrir l’espace d’administration.
2. Ouvrir **Mode d’exploitation et identité juridique**.
3. Laisser **Activer la version payante** désactivé.
4. Remplir le formulaire affiché directement dans la carte d’administration.
5. Renseigner les champs obligatoires de la bêta :
   - nom réel de l’éditeur ;
   - adresse postale juridiquement utilisable ;
   - téléphone ;
   - e-mail de contact ;
   - directeur de publication.
6. Vérifier ou ajuster, dans la section **Hébergement**, l’hébergeur et son adresse.
7. Vérifier que le statut affiche **Profil juridique complet**.
8. Contrôler les onglets Mentions légales, Confidentialité et CGU depuis un parcours non connecté.

Aucune identité n’est inventée par l’application. Tant que les champs obligatoires ne sont pas renseignés, la page juridique affiche un avertissement et le mode commercial reste verrouillé.

## Fonctionnement du formulaire administrateur

Le formulaire intégré permet de modifier :

- le nom réel de l’éditeur ;
- l’adresse juridiquement utilisable ;
- le téléphone ;
- l’adresse e-mail de contact ;
- le directeur de publication ;
- les informations de société préparant le futur passage au payant ;
- les informations de l’hébergeur.

Les contrôles empêchent l’enregistrement d’une adresse e-mail ou d’un téléphone manifestement invalide. Le statut de complétude se met à jour pendant la saisie.

Après enregistrement, `app_config/legal` est mis à jour. La page juridique publique récupère ensuite les valeurs à travers `getPublicLegalConfig`. Aucun nouveau build de l’application n’est nécessaire pour modifier le contenu ; la Cloud Function doit simplement avoir été déployée avec cette version.

## Exposition publique sécurisée

`getPublicLegalConfig` est accessible sans connexion afin que les mentions légales soient consultables avant l’inscription. La réponse est filtrée et limitée aux champs suivants :

- mode d’exploitation et versions juridiques ;
- date d’entrée en vigueur ;
- identité et coordonnées légales de l’éditeur ;
- informations de société lorsqu’elles existent ;
- hébergeur et adresse d’hébergement.

La fonction ne retourne notamment aucun identifiant administrateur, rôle, jeton, secret, historique interne ou donnée de paiement. L’écriture reste réservée à l’administration via les règles Firestore existantes.

## Garanties du mode `free_beta`

- aucun prix ni comparateur de formules visible ;
- aucun bouton de souscription ou de gestion Stripe ;
- aucun préchargement de session Checkout ;
- refus client des actions d’abonnement ;
- refus serveur de la Cloud Function Checkout ;
- section utilisateur remplacée par la carte **Accès bêta gratuit** ;
- documents juridiques `beta-free-v1`, `cgu-beta-free-v1` et `privacy-beta-free-v1` ;
- aucune donnée bancaire demandée pour accéder au service ;
- preuve de l’acceptation des CGU et de la politique de confidentialité enregistrée sur le compte ;
- historique de chaque changement de mode dans `legal_mode_history`.

## Activation future de la version payante

Avant d’utiliser le toggle, compléter dans la section **Informations de société** :

- dénomination sociale ;
- forme juridique ;
- SIREN ;
- RCS lorsque disponible ;
- capital social ;
- numéro de TVA intracommunautaire lorsque applicable.

Le toggle exécute une bascule atomique :

- `operatingMode = commercial` ;
- `subscriptionSectionEnabled = true` ;
- `stripeEnabled = true` ;
- `freeAccessMode = false` ;
- versions juridiques commerciales activées ;
- `requiresReacceptance = true` lors d’un changement de mode ;
- écriture d’une entrée d’historique.

Si le profil commercial est incomplet, la bascule est refusée.

## Retour d’urgence à la bêta gratuite

Désactiver le toggle. La même transaction remet immédiatement :

- `operatingMode = free_beta` ;
- `subscriptionSectionEnabled = false` ;
- `stripeEnabled = false` ;
- `freeAccessMode = true`.

Le garde serveur refuse ensuite toute nouvelle création de Checkout, même en cas d’ancien client ou d’appel direct à la fonction.

## Versions juridiques

| Mode | Mentions | CGU | Confidentialité |
| --- | --- | --- | --- |
| Bêta gratuite | `beta-free-v1` | `cgu-beta-free-v1` | `privacy-beta-free-v1` |
| Commercial | `commercial-v1` | `cgu-commercial-v1` | `privacy-commercial-v1` |

La date affichée provient de `effectiveDate`. Elle ne dépend jamais de l’heure d’ouverture de la page.

## Preuve d’acceptation

Après une inscription, le compte utilisateur reçoit :

```text
legalAcceptance.operatingMode
legalAcceptance.legalVersion
legalAcceptance.cguVersion
legalAcceptance.privacyVersion
legalAcceptance.acceptedAt
legalAcceptance.source
```

Une évolution substantielle peut utiliser `requiresReacceptance` pour déclencher un nouvel écran d’acceptation avant l’accès aux fonctions concernées.

## Configuration de secours au build

Les mentions légales peuvent conserver des valeurs embarquées avec les `dart-define` suivants :

```text
LEGAL_PUBLISHER_NAME
LEGAL_PUBLISHER_ADDRESS
LEGAL_PUBLISHER_PHONE
LEGAL_CONTACT_EMAIL
LEGAL_PUBLICATION_DIRECTOR
LEGAL_COMPANY_NAME
LEGAL_COMPANY_FORM
LEGAL_COMPANY_SIREN
LEGAL_COMPANY_RCS
LEGAL_COMPANY_CAPITAL
LEGAL_COMPANY_VAT
```

Ces valeurs sont uniquement un secours si la configuration distante est momentanément indisponible. Après le premier enregistrement dans l’administration et le déploiement de `getPublicLegalConfig`, les valeurs de `app_config/legal` sont prioritaires pour tous les visiteurs, y compris non connectés.

## Validation avant fusion et déploiement

- `flutter analyze` ;
- test du formulaire administrateur et de ses validations ;
- test du chargement public sans accès Firestore client ;
- test du filtrage serveur des champs publics ;
- tests ciblés du mode d’exploitation ;
- tests de la configuration abonnement ;
- tests de la page d’inscription ;
- tests des widgets abonnement ;
- compilation TypeScript des Functions ;
- tests du garde de paiement serveur ;
- tests complets Flutter sans abaisser les seuils existants ;
- vérification manuelle non connectée des trois documents juridiques ;
- vérification admin de la bascule gratuite → commerciale → gratuite sur un environnement de test ;
- contrôle qu’aucune session Stripe n’est créée en `free_beta`.

## Déploiement

Le déploiement de cette évolution doit inclure :

- Flutter Web / Hosting ;
- Cloud Functions, notamment `getPublicLegalConfig` et le garde Checkout ;
- configuration Firestore initialisée depuis l’administration.

Ne pas activer le mode commercial en production tant que la structure juridique, les informations de société, les tarifs et les conditions commerciales ne sont pas validés.
