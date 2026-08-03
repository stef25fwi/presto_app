# Point 7 — Conversation E2E

## Objectif

Certifier le cycle complet d’une conversation iliprestō entre deux comptes distincts : création du fil depuis une annonce, envoi, réception, lecture, archivage, modération et suppression.

## Parcours obligatoires

| Parcours | Automatisation | Appareil réel | Statut initial |
|---|---:|---:|---|
| Envoyer et recevoir un message texte | requis | requis | à valider |
| Envoyer une photo | requis | requis | à valider |
| Ouvrir la photo en plein écran avec watermark | requis | requis | à valider |
| Envoyer un fichier autorisé | requis | requis | à valider |
| Enregistrer, préécouter et envoyer un audio | requis | requis | à valider |
| Annuler puis confirmer chaque suppression | requis | requis | partiellement couvert |
| Marquer les messages comme lus | requis | requis | à valider |
| Archiver et restaurer une conversation | requis | requis | à valider |
| Bloquer un utilisateur | requis | requis | à valider |
| Signaler un message | requis | requis | à valider |

## Critères de réussite

- aucune écriture directe ne permet de contourner les autorisations serveur ou Firestore ;
- les médias restent accessibles uniquement aux participants autorisés ;
- les erreurs réseau, upload et lecture sont visibles et récupérables ;
- une action utilisateur ne produit jamais deux messages ou deux suppressions ;
- les confirmations sont obligatoires pour texte, fichier, photo et audio ;
- les statuts de lecture sont cohérents entre les deux comptes ;
- les tests automatisés et les preuves sur appareils réels sont associés au même SHA.

## État au démarrage du lot

Le dépôt possède déjà plusieurs tests ciblés du fil de conversation, de la prévisualisation audio, des actions publiques, de la sécurité et des confirmations. La certification reste volontairement ouverte tant que la matrice complète et les notifications réelles ne sont pas prouvées.
