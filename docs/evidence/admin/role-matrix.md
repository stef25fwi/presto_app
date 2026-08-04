# Matrice des rôles d’administration — point 9

## Principe

Toute opération d’administration ou de modération est un appel serveur. Le
client n’exécute jamais l’action lui-même : il demande, le backend vérifie le
rôle porté par le jeton Firebase, puis agit.

La source d’autorité est `quality/admin-authority-matrix.json`. Elle est
confrontée au code par `tools/quality/check_admin_authority.mjs`, dans les
deux sens :

1. chaque opération déclarée doit exister et appliquer **exactement** les
   rôles annoncés ;
2. toute opération d’administration présente dans le code mais absente de la
   matrice fait échouer le contrôle.

Le second sens est le plus important : sans lui, une nouvelle porte d’entrée
ajoutée plus tard passerait inaperçue.

## Rôles

| Rôle | Portée |
|---|---|
| `moderator` | Traite les signalements et les contenus, sans toucher aux rôles ni aux comptes. |
| `admin` | Opère l’ensemble des outils d’exploitation et de modération. |
| `superadmin` | Hérite d’`admin` et reste seul destinataire des évolutions de privilèges les plus sensibles. |

## Opérations certifiées

| Opération | Rôles acceptés | Mutation | App Check | Journal |
|---|---|---|---|---|
| `applyUserRoleClaims` | admin, superadmin | oui | appliqué | `writeAdminActionLog` |
| `logAdminAction` | admin, moderator, superadmin | oui | appliqué | `writeAdminActionLog` |
| `reviewListingPhoto` | admin, moderator, superadmin | oui | appliqué | `writeAdminActionLog` |
| `adminBulkDeleteListings` | admin, superadmin | oui | appliqué | `writeAdminActionLog` |
| `adminModerateReviewV2` | admin, moderator, superadmin | oui | appliqué | collection dédiée de modération |
| `adminUnblockConversation` | admin, superadmin | oui | **désactivé** | `writeAdminActionLog` |
| `adminGetAiMetrics` | admin, superadmin | non | appliqué | lecture seule |
| `adminGenerateVideo` | admin, superadmin | oui | appliqué | `writeAdminActionLog` |
| `adminListGeneratedVideos` | admin, superadmin | non | appliqué | lecture seule |
| `adminDeleteGeneratedVideo` | admin, superadmin | oui | appliqué | `writeAdminActionLog` |
| `generatePaymentInfoAudio` | admin, superadmin | oui | appliqué | dérogation écrite |
| `generatePaymentInfoAudioDraft` | admin, superadmin | oui | appliqué | dérogation écrite |
| `publishPaymentInfoAudioDraft` | admin, superadmin | oui | appliqué | `writeAdminActionLog` |
| `broadcastTestNotification` | admin, superadmin | oui | appliqué | `writeAdminActionLog` |

Trois gardes locales portent le contrôle de rôle pour plusieurs opérations et
sont vérifiées séparément : `requireAdmin` dans le module vidéo, `requireAdmin`
dans le module audio de paiement, et `requireAdminAccess` dans la messagerie.

## Impossibilité d’élévation côté client

Les revendications de rôle proviennent du jeton Firebase, écrit uniquement par
`syncMarketplaceClaims` côté serveur. Côté Firestore, les 48 champs de
`protectedUserFields()` — dont `roles`, `role`, `primaryRole`, `adminRole`,
`admin`, `superadmin`, `moderator`, `isAdmin`, `isModerator`, `isSuperadmin`
et `marketplaceAccess` — sont refusés en écriture cliente. Le vérificateur
échoue si l’un de ces champs disparaît de la liste, ou si la liste est déclarée
sans être appliquée.

## Écart connu

`adminUnblockConversation` s’exécute avec `enforceAppCheck: false`, hérité de
`ADMIN_MESSAGING_CALLABLE_OPTIONS`. L’opération reste protégée par le rôle et
désormais journalisée, mais elle n’exige pas d’attestation d’application.

Cet écart est déclaré comme dérogation ouverte dans la matrice, rattachée au
point 12 (sécurité et conformité). Le contrôle `app-check-admin` du registre
reste `pending` tant qu’il n’est pas fermé : le vérificateur refuse par ailleurs
toute désactivation d’App Check qui ne serait pas accompagnée d’une dérogation
ouverte et attribuée.

## Reproduire

```bash
node tools/quality/check_admin_authority.mjs
node tools/quality/check_admin_authority.test.mjs
```

Le rapport est écrit dans `build/quality/admin-authority-report.json`.
