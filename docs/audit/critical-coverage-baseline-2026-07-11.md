# Baseline de couverture critique — 11 juillet 2026

Cette photographie distingue la couverture des lignes présentes dans LCOV et la proportion de fichiers critiques réellement suivis par les tests.

## Résultats

| Module | Fichiers suivis | Couverture actuelle | Plancher bloquant | Cible |
|---|---:|---:|---:|---:|
| Authentification | 17/18 — 94,44 % | 2,93 % | 2 % | 85 % |
| Abonnements et paiement | 8/9 — 88,89 % | 2,01 % | 1 % | 90 % |
| Publication d’annonces | 9/11 — 81,82 % | 23,53 % | 23 % | 85 % |
| Messagerie | 3/4 — 75 % | 0,25 % | 0,2 % | 85 % |
| Administration | 46/49 — 93,88 % | 0,65 % | 0,5 % | 85 % |
| Parcours entrepreneur | 6/6 — 100 % | 48,39 % | 48 % | 85 % |

## Fichiers critiques non suivis par LCOV

- `lib/pages/auth/auth_gate.dart` ;
- `lib/features/subscriptions/subscription_return_history_web.dart` ;
- `lib/features/publish_ai/publish_ai_pipeline.dart` ;
- `lib/features/publish_ai/publish_ai_state.dart` ;
- `lib/data/marketplace/chat_repository.dart` ;
- `lib/admin/messaging/admin_conversations_page.dart` ;
- `lib/admin/messaging/admin_message_reports_page.dart` ;
- `lib/admin/messaging/admin_messaging_users_page.dart`.

## Lecture

La couverture globale d’environ 11 % masquait des domaines encore presque non testés. Les planchers ci-dessus ne constituent pas un niveau acceptable : ils empêchent seulement une régression pendant la montée progressive vers 85 %, et 90 % pour paiement/abonnement.

## Ordre de rattrapage

1. Messagerie : repository, liste et conversation.
2. Paiement et abonnements : checkout, URL Stripe, cache de destination, erreurs et droits.
3. Authentification : gate, erreurs, reconnexion et fournisseurs sociaux.
4. Administration : suppressions, statistiques et historique.
5. Publication : pipeline IA et état non encore instrumentés.
6. Parcours entrepreneur : compléter les branches restantes jusqu’à 85 %.

Chaque lot doit augmenter à la fois la couverture des lignes et la proportion de fichiers suivis. Les seuils ne doivent jamais être abaissés pour faire passer une PR.
