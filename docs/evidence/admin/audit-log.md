# Journal des actions d’administration — point 9

## Règle

Une mutation d’administration doit rester explicable après coup. Le point 9
exige donc que chaque opération modifiant l’état laisse une trace nominative,
ou qu’elle porte une dérogation écrite justifiant son absence.

Cette règle est appliquée par `tools/quality/check_admin_authority.mjs` : une
opération déclarée `mutating` sans trace et sans `auditWaiver` accepté fait
échouer le contrôle.

## Écriture de la trace

`functions/src/modules/marketplace/services/admin_audit.ts` écrit un document
par action dans la collection des actions d’administration :

| Champ | Contenu |
|---|---|
| `actorId` | Identifiant de l’administrateur |
| `actorRole` | `admin` ou `superadmin` résolu depuis le jeton |
| `actionType` | Nature de l’action |
| `targetType` / `targetId` | Objet visé |
| `before` / `after` | État avant et après, lorsque pertinent |
| `metadata` | Contexte complémentaire |
| `createdAt` | Horodatage serveur |

Aucun contenu utilisateur n’est recopié dans la trace au-delà de ce qui est
nécessaire pour expliquer la décision.

## Traces ajoutées lors de ce lot

L’audit initial du lot 9 a relevé sept mutations d’administration sans
journal. Cinq ont été corrigées, deux ont reçu une dérogation motivée.

| Opération | Décision | Motif |
|---|---|---|
| `broadcastTestNotification` | trace ajoutée | Une diffusion atteint tous les destinataires. |
| `adminUnblockConversation` | trace ajoutée | Le déblocage force l’état d’une conversation privée. |
| `adminGenerateVideo` | trace ajoutée | Consomme un service payant et publie un média. |
| `adminDeleteGeneratedVideo` | trace ajoutée | Suppression irréversible, chemin de stockage conservé. |
| `publishPaymentInfoAudioDraft` | trace ajoutée | Rend l’audio visible des utilisateurs. |
| `generatePaymentInfoAudio` | dérogation acceptée | Génération interne sans effet visible. |
| `generatePaymentInfoAudioDraft` | dérogation acceptée | Brouillon non diffusé. |

Les deux dérogations sont cohérentes entre elles : la trace est portée par la
publication, qui est le seul moment où l’état devient visible des utilisateurs.

## Traces préexistantes

`applyUserRoleClaims`, `logAdminAction`, `reviewListingPhoto` et
`adminBulkDeleteListings` écrivaient déjà dans le journal.
`adminModerateReviewV2` alimente une collection de modération dédiée, avec la
décision et sa note.

## Reproduire

```bash
node tools/quality/check_admin_authority.mjs
node tools/quality/check_admin_authority.test.mjs
npm --prefix functions test
```

## Reste à faire

La lecture et l’exploitation du journal côté production — rétention, export et
consultation par un tiers — relèvent des points 12 et 18. Le contrôle
`audit-log` du présent registre couvre l’écriture et sa vérification
automatique, pas encore l’exploitation opérationnelle.
