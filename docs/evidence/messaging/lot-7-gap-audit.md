# Lot 7 — Audit préparatoire Messagerie complète

Date de démarrage : 4 août 2026

## Cadre

Le lot 7 appartient au programme séquentiel `ilipresto-18-point-100-percent`. Il reste officiellement `blocked` tant que les lots 2 à 6 ne sont pas `verified`. Ce document démarre les travaux préparatoires sans modifier l’ordre du superviseur.

## Objectif du lot

Certifier la messagerie texte, média, audio, modération et notifications, avec preuves sur appareils réels et contrôles backend.

## État du registre au démarrage

| Contrôle | État initial | Travail de clôture |
|---|---|---|
| text-messaging | in_progress | Consolider les tests envoi, réception, erreur, reprise et lecture. |
| photo-file-messaging | in_progress | Vérifier upload, affichage, téléchargement, suppression et erreurs. |
| audio-messaging | in_progress | Vérifier enregistrement, préécoute, envoi, lecture et suppression. |
| fullscreen-watermark | in_progress | Certifier l’ouverture plein écran et le watermark sur chaque format d’image. |
| delete-confirmations | in_progress | Certifier les confirmations pour texte, photo, fichier et audio. |
| moderation-block-report | in_progress | Vérifier blocage, déblocage, signalement, modération et droits serveur. |
| archive-read-state | pending | Ajouter les preuves d’archivage, désarchivage, lus/non lus et reçus de lecture. |
| backend-authorization | pending | Auditer Rules, callables et refus d’accès inter-utilisateurs. |
| push-foreground | pending | Tester les notifications en premier plan sur appareils réels. |
| push-background | pending | Tester les notifications en arrière-plan sur appareils réels. |
| push-terminated | pending | Tester les notifications application fermée et l’ouverture de la bonne conversation. |
| real-device-matrix | pending | Produire une matrice Web, Android et iOS avec versions, appareils et résultats. |

## Ordre d’exécution préparatoire

1. Consolider les parcours texte, média, audio, plein écran et suppression déjà partiellement couverts.
2. Fermer `archive-read-state` avec tests déterministes et preuve fonctionnelle.
3. Fermer `backend-authorization` avec Rules Emulator et tests Functions.
4. Préparer la matrice de notifications push et les scénarios appareils réels.
5. Exécuter les validations complètes du lot : analyse Flutter, tests avec couverture, tests Functions et Firestore Emulator.
6. Ne passer les contrôles à `verified` qu’après preuve réelle et reproductible.

## Critères de clôture

- texte, photos, fichiers et audio validés ;
- plein écran, watermark et confirmations de suppression couverts ;
- blocage, signalement, archivage et états de lecture cohérents ;
- notifications certifiées en premier plan, arrière-plan et application fermée ;
- `quality/messaging-readiness.json` entièrement `verified` ;
- les trois preuves obligatoires du lot présentes et complètes.
