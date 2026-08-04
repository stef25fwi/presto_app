# Modération de bout en bout — point 9

## Portée

Quatre familles doivent être modérables : annonces, avis, messages et
utilisateurs. Cette preuve décrit, pour chacune, le chemin serveur, la trace
laissée et l’état réel de la vérification.

## Annonces

| Étape | Mécanisme |
|---|---|
| Signalement | `reportListing` |
| Revue photo | `reviewListingPhoto`, rôles moderator/admin/superadmin |
| Suppression en masse | `adminBulkDeleteListings`, motif obligatoire |
| Trace | `writeAdminActionLog` sur les trois opérations |

La suppression en masse refuse un appel sans motif : la contrainte est portée
par le backend, pas par l’écran.

## Avis

`adminModerateReviewV2` accepte les rôles moderator, admin et superadmin. La
décision et sa note sont écrites dans une collection de modération dédiée,
dans la même transaction que la mise à jour de l’avis — un avis ne peut donc
pas changer d’état sans que la décision correspondante existe.

## Messages et conversations

Le centre de messagerie d’administration dispose de services distincts pour la
modération, l’audit, les métriques et les paramètres. Le déblocage d’une
conversation passe par `adminUnblockConversation`, désormais journalisé.

Couverture de tests existante côté client, exécutée par la suite Flutter :

- politique d’accès et pagination de l’espace messagerie ;
- pages signalements, détail de signalement, conversations, pièces jointes ;
- services de modération, d’audit, d’analytique et de paramètres ;
- journaux d’audit et moniteur de notifications.

## Utilisateurs et rôles

`applyUserRoleClaims` est la seule voie d’attribution de rôle. Elle exige
admin ou superadmin, synchronise les revendications Firebase et le document
utilisateur, et journalise l’action. Aucun champ de rôle n’est inscriptible
depuis le client — voir [`role-matrix.md`](role-matrix.md).

## Vérification automatique

```bash
node tools/quality/check_admin_authority.mjs
node tools/quality/check_admin_authority.test.mjs
node tools/quality/check_admin_readiness.mjs
npm --prefix functions test
npm --prefix functions run test:firestore
flutter test --coverage --reporter expanded
```

## État

Acquis et vérifiés automatiquement :

- l’autorité, les rôles et la journalisation de chaque opération de modération
  (contrôles `role-matrix`, `server-authority`, `no-client-elevation` et
  `audit-log` à `verified`) ;
- la couverture unitaire et widget de l’espace de modération messagerie.

Restent à produire :

- une exécution de bout en bout sur environnement réel — signalement déposé
  par un utilisateur, décision prise par un modérateur, effet constaté côté
  utilisateur et trace relue — d’où `moderation-device-evidence` maintenu
  `pending` ;
- l’extension de la même couverture aux parcours annonces et avis côté client,
  d’où `moderation-coverage` maintenu `in_progress`.
