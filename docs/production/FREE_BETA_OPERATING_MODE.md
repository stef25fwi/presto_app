# Mode d’exploitation Ilipresto — bêta gratuite / version payante

## Objectif

Ilipresto démarre en **bêta gratuite**. Aucun abonnement, paiement, renouvellement ou commission n’est activé. Le passage à la version payante est ensuite réalisé depuis un toggle unique dans l’administration, uniquement lorsque les informations juridiques commerciales sont complètes.

## Source de vérité

Deux documents Firestore sont utilisés :

- `app_config/legal` : mode d’exploitation, versions juridiques, date d’entrée en vigueur et identité de l’éditeur ;
- `app_config/subscriptions` : miroir opérationnel utilisé par l’interface et les fonctions de paiement.

Le mode canonique est :

- `free_beta` : accès gratuit, Stripe désactivé, section abonnements masquée, droits gratuits actifs ;
- `commercial` : section abonnements et Stripe activés, droits définis par les formules.

Les anciens champs restent présents pour compatibilité, mais ils sont neutralisés lorsqu’ils contredisent `free_beta`.

## Mise en service initiale

1. Ouvrir l’espace d’administration.
2. Ouvrir **Mode d’exploitation Ilipresto**.
3. Laisser **Activer la version payante** désactivé.
4. Ouvrir **Configurer l’identité juridique**.
5. Renseigner les champs obligatoires de la bêta :
   - nom réel de l’éditeur ;
   - adresse postale juridiquement utilisable ;
   - téléphone ;
   - e-mail ;
   - directeur de publication ;
   - hébergeur et adresse de l’hébergeur.
6. Vérifier que le statut affiche **Profil juridique complet**.
7. Contrôler les onglets Mentions légales, Confidentialité et CGU depuis un parcours non connecté.

Aucune identité n’est inventée par l’application. Tant que les champs obligatoires ne sont pas renseignés, la page juridique affiche un avertissement et le mode commercial reste verrouillé.

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

Avant d’utiliser le toggle, compléter dans le profil juridique :

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

Les mentions légales peuvent disposer de valeurs embarquées avec les `dart-define` suivants :

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

Ces valeurs servent de secours. La configuration Firestore gérée depuis l’administration reste prioritaire pour les utilisateurs autorisés à la lire.

## Validation avant fusion et déploiement

- `flutter analyze`
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
- Cloud Functions pour le garde Checkout ;
- configuration Firestore initialisée depuis l’administration.

Ne pas activer le mode commercial en production tant que la structure juridique, les informations de société, les tarifs et les conditions commerciales ne sont pas validés.
