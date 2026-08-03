# Point 7 — Matrice médias

| Type | Création | Prévisualisation | Envoi | Réception | Plein écran / lecture | Suppression confirmée | Limites et sécurité |
|---|---|---|---|---|---|---|---|
| Texte | à certifier | n/a | à certifier | à certifier | n/a | à certifier | longueur, contenu vide, doublons |
| Photo | à certifier | à certifier | à certifier | à certifier | watermark obligatoire | à certifier | taille, type MIME, accès participant |
| Fichier | à certifier | nom + taille | à certifier | à certifier | ouverture contrôlée | à certifier | extension, taille, URL signée |
| Audio | à certifier | lecture locale | à certifier | à certifier | lecteur intégré | à certifier | durée, taille, permissions micro |

## Viewports

Les parcours doivent être validés au minimum à 320, 360, 390, 430, 600, 768, 1024, 1280 et 1440 px, avec texte agrandi à 200 % sur les largeurs représentatives.

## États obligatoires

Chaque média doit exposer des états cohérents : sélection, préparation, upload, envoyé, reçu, lu, erreur récupérable et supprimé. Une reprise réseau ne doit pas créer de doublon.

## Sécurité

- validation côté client pour l’ergonomie et côté backend/règles pour l’autorité ;
- accès réservé aux participants de la conversation ;
- aucune URL publique durable pour un média privé ;
- nettoyage du stockage après suppression autorisée ;
- journalisation sans contenu privé ni URL sensible.
