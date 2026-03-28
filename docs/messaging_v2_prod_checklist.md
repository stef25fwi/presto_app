# Checklist Production - Messagerie V2

## Statut actuel

- La route `/messages` ouvre la V2.
- La route `/messages-2` reste un alias explicite vers la meme page.
- La liste V2 lit Firestore via le champ canonique `participants`.
- L'audit Firestore courant ne remonte aucune conversation mal normalisee sur les 5 documents scannes.

## Champs obligatoires - conversation

Chaque document `conversations/{conversationId}` doit exposer :

- `participants`
- `participant_ids`
- `participantIds`
- `userIds`
- `memberIds`
- `participantNames` et `participant_names`
- `offerId` et `offer_id`
- `offerTitle` et `offer_title`
- `lastMessage` et `last_message`
- `lastSenderId` et `last_sender_id`
- `lastSenderName` et `last_sender_name`
- `messageCount` et `message_count`
- `lastMessageAt` et `last_message_at`
- `updatedAt` et `updated_at`
- `createdAt` et `created_at`
- `unreadCount` et `unread_count`
- `lastReadAt` et `last_read_at`
- `archivedBy`
- `blockedBy`
- `status`

Source canonique d'ecriture :

- `functions/src/modules/messaging/mirror.ts`

## Champs obligatoires - message

Chaque document `conversations/{conversationId}/messages/{messageId}` doit exposer :

- `text` et `body`
- `senderId` et `sender_id`
- `senderName` et `sender_name`
- `createdAt` et `created_at`
- `isFirstMessage`

## Requetes Firestore utilisees par la V2

Liste des conversations :

- `conversations.where('participants', arrayContains: userId)`

Lecture d'une conversation ciblee par deep link :

- `conversations.doc(conversationId).get()`

Fil de discussion live :

- `conversations/{id}/messages.orderBy('createdAt', descending: true).limit(50)`

Pagination anciens messages :

- `conversations/{id}/messages.orderBy('createdAt', descending: true).startAfterDocument(cursor).limit(50)`

Badge non lu visible :

- `users/{uid}.inboxCounts.unreadMessages`
- recalcul backend aligne sur `participants`

## Index Firestore necessaires

Necessaires pour la V2 elle-meme :

- aucun index composite supplementaire pour la liste V2 simple sur `participants`
- aucun index composite supplementaire pour le thread sur `messages.createdAt`

Necessaires pour les workflows backend lies a la conversation :

- `conversations: participants CONTAINS + offerId ASC`
- `conversations: participants CONTAINS + lastMessageAt DESC`

Etat du fichier d'index :

- present dans `firestore.indexes.json`

## Regles Firestore necessaires

Lecture conversation :

- l'utilisateur doit apparaitre dans au moins un alias participants

Lecture sous-collection messages :

- l'utilisateur doit etre participant de la conversation parente

Etat actuel :

- conforme dans `firestore.rules`

## Cablage fonctions obligatoire

- `ensureOfferConversation`
- `sendConversationMessage`
- `markConversationRead`
- `archiveConversation`
- `unarchiveConversation`
- `blockConversation`
- `unblockConversation`
- `deleteConversation`
- `deleteConversationMessage`
- trigger `onConversationSubMessageCreated`
- compteur `refreshUnreadMessageCount`

## Anti-perte / anti-invisibilite

- La liste et le badge doivent partager le meme critere de visibilite principal : `participants`.
- Toute creation ou mise a jour de conversation doit passer par `buildConversationMirrorFields`.
- Toute conversation sans `participants` canonique doit etre backfill avant mise en prod.
- Toute conversation avec `messageCount > 0` mais sans `lastMessage` ou `lastMessageAt` doit etre corrigee.
- Toute conversation avec `participants` incomplet par rapport aux maps `unreadCount`, `lastReadAt`, `archivedBy`, `blockedBy` doit etre corrigee.

## Checklist release 10/10

- `npm --prefix functions test`
- `flutter test test/app_route_parser_test.dart`
- `flutter analyze`
- `node tools/audit_conversations_firestore.cjs --sample=10`
- `npm --prefix functions run messaging:backfill:mirror:dry-run`
- verifier qu'aucune conversation n'est signalee sur :
- `missingPrimaryParticipants`
- `inconsistentAliasArrays`
- `missingParticipantNames`
- `missingOfferMetadata`
- `hiddenWithoutRenderableContent`
- `orphanMapKeysWithoutParticipants`
- `zeroMessageButLastMessagePresent`
- `nonZeroMessageButNoLatestMetadata`

## Etat controle le 2026-03-28

- audit conversations : 5 scannees
- aucune anomalie critique detectee
- tests functions : 44/44
- test route parser Flutter : OK
- analyse Flutter : OK