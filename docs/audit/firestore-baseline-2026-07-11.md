# Baseline Firestore — 11 juillet 2026

Rapport produit automatiquement par la PR #187.

## Mesures

| Indicateur | Valeur |
|---|---:|
| Fichiers utilisant Firestore | 89 |
| `FirebaseFirestore.instance` | 113 |
| Collections littérales | 135 |
| Filtres `where` | 281 |
| Tris `orderBy` | 41 |
| Limites explicites | 62 |
| Curseurs `startAfter*` | 8 |
| Listeners `snapshots` | 34 |
| Lectures `get` | 98 |
| Agrégations `count` | 7 |
| Write batches | 14 |
| Transactions détectées | 0 |

Ces compteurs sont des signaux statiques : ils ne mesurent pas directement le nombre de lectures facturées.

## Collections les plus référencées

| Collection | Occurrences |
|---|---:|
| `users` | 51 |
| `conversations` | 10 |
| `parcours` | 8 |
| `pro_profiles` | 6 |
| `listings` | 5 |
| `notifications` | 5 |
| `messages` | 4 |
| `toolbox_journey_index` | 4 |
| `toolbox_journeys` | 4 |
| `pros` | 3 |
| `favorites` | 3 |

## Priorités de revue

### P0 — parcours très utilisés

- `lib/pages/account_page.dart` : plusieurs lectures et un listener sans pagination visible ;
- `lib/pages/consult_offers_page.dart` : cinq lectures et aucune limite visible dans le fichier ;
- `lib/pages/messages/conversation_thread_page.dart` : quatre listeners et sept lectures ;
- `lib/pages/messages/conversations_list_page.dart` : trois listeners, quatre lectures et un seul `limit` ;
- `lib/admin/messaging/services/admin_messaging_service.dart` : quatre listeners et quatre lectures, avec pagination partielle.

### P1 — configuration et contenu

- `payment_info_audio_service.dart` ;
- `hero_slides_service.dart` ;
- `subscription_config_service.dart` ;
- `admin_messaging_settings_service.dart` ;
- `fiche_pro_page.dart`.

## Première correction appliquée

`ListingRepository.watchPublicListings` est désormais borné à 100 documents maximum. `fetchPublicListings` borne également toute valeur fournie entre 1 et 100. Des tests d’architecture empêchent la disparition accidentelle de ces limites.

## Prochaines actions

1. Mesurer les lectures réelles par écran avec Emulator Suite et production.
2. Remplacer les listes non bornées par pagination par curseur.
3. Justifier et documenter chaque listener temps réel.
4. Éliminer les lectures N+1 dans compte, fiches pro et messagerie.
5. Construire des agrégats pour les tableaux de bord.
6. Réexécuter ce rapport après chaque lot et comparer les valeurs.
