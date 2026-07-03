# Audit CGU — ilipresto

Date UTC : 2026-07-03T13:44:11Z

## Résumé

- ✅ OK probable : 14
- 🟡 À vérifier / partiel : 3
- ❌ Manquant probable : 8

## Fichiers analysés contenant du contenu légal / CGU probable

- `docs/PRE_PROD_REVIEW_20260618.md`
- `docs/assets/assets/data/cities/cities_62.json`
- `docs/monitoring_incident_rollback.md`
- `lib/config/ai_prompts.dart`
- `lib/core/firebase_contract.dart`
- `lib/data/marketplace/marketplace_listing_ui_mapper.dart`
- `lib/dev/page_capture_catalog_page.dart`
- `lib/dev/seed_offers.dart`
- `lib/features/account/signed_out_account_fallback.dart`
- `lib/features/auth/services/user_profile_service.dart`
- `lib/features/offers/public_offers_read_diagnostics.dart`
- `lib/features/trust_score/trust_score_models.dart`
- `lib/features/trust_score/trust_score_widgets.dart`
- `lib/main.dart`
- `lib/pages/account_page.dart`
- `lib/pages/admin/widgets/payment_info_audio_admin_section.dart`
- `lib/pages/admin_space_page.dart`
- `lib/pages/auth/register_page.dart`
- `lib/pages/consult_offers_page.dart`
- `lib/pages/fiche_pro_page.dart`
- `lib/pages/home_page.dart`
- `lib/pages/legal_info_page.dart`
- `lib/pages/messages/conversation_thread_page.dart`
- `lib/pages/messages/conversations_list_page.dart`
- `lib/pages/offers/offer_details_page.dart`
- `lib/pages/offers/widgets/payment_info_popup.dart`
- `lib/pages/pro_profile_page.dart`
- `lib/pages/publish_offer_page.dart`
- `lib/pages/toolbox_je_me_lance_page.dart`
- `lib/pages/user_offers_section.dart`
- `lib/services/admin_broadcast_service.dart`
- `lib/services/ai/enhanced_listing_ai_service.dart`
- `lib/services/inbox_counts.dart`
- `lib/services/marketplace_publish_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/public_offers_query_helpers.dart`
- `lib/widgets/account_notifications_tile.dart`
- `lib/widgets/account_profile_sections.dart`
- `lib/widgets/ai_publish_control.dart`
- `lib/widgets/home_interactions.dart`
- `lib/widgets/offer_card.dart`

## Comparaison point par point

| Point CGU | Statut | Preuves trouvées | Action recommandée |
|---|---:|---|---|
| Objet de l’application | ✅ OK probable | `lib/pages/legal_info_page.dart:238` — La Plateforme n'a pas vocation à collecter des données dites "sensibles" (santé, opinions, etc.). Nous vous invitons à ne pas publier de telles informations dans vos annonces ou messages.<br>`lib/pages/legal_info_page.dart:339` — La Plateforme est un service de mise en relation. L’Éditeur n’est pas partie aux accords, prestations, devis, contrats, paiements ou litiges pouvant intervenir entre Annonceur et Prestataire. | Décrire clairement à quoi sert ilipresto. |
| Rôle de la plateforme : mise en relation / publication d’annonces | ✅ OK probable | `lib/pages/legal_info_page.dart:147` — Plateforme de mise en relation locale permettant la publication et la consultation d'annonces de services, ainsi que l'échange entre utilisateurs via une messagerie.<br>`lib/pages/legal_info_page.dart:328` — • la publication d’annonces de services par des utilisateurs (ci-après « Annonceurs »),<br>`lib/pages/legal_info_page.dart:330` — • la mise en relation et l’échange via une messagerie interne.<br>`lib/pages/legal_info_page.dart:339` — La Plateforme est un service de mise en relation. L’Éditeur n’est pas partie aux accords, prestations, devis, contrats, paiements ou litiges pouvant intervenir entre Annonceur et Prestataire.<br>`lib/pages/legal_info_page.dart:394` — title: "Publication d'annonces", | Dire que la plateforme permet de publier/consulter des annonces et de mettre en relation les utilisateurs. |
| ilipresto n’est pas employeur | ❌ Manquant probable | Aucune preuve trouvée automatiquement | Préciser explicitement qu’ilipresto n’est pas employeur des utilisateurs/prestataires. |
| ilipresto n’est pas mandataire de paiement entre particuliers | ❌ Manquant probable | Aucune preuve trouvée automatiquement | Dire qu’ilipresto n’agit pas comme mandataire ou intermédiaire de paiement entre particuliers. |
| Chaque utilisateur reste responsable de ses prestations | ✅ OK probable | `lib/pages/legal_info_page.dart:340` — Chaque utilisateur demeure seul responsable des engagements qu’il prend et de la conformité légale de son activité.<br>`lib/pages/legal_info_page.dart:365` — L’utilisateur est responsable : | Indiquer que l’utilisateur est seul responsable de ses annonces, prestations, déclarations et obligations. |
| Conditions d’inscription | ✅ OK probable | `lib/dev/page_capture_catalog_page.dart:158` — description: 'Inscription nouveau compte.',<br>`lib/pages/admin_space_page.dart:1194` — trendLabel: 'Inscriptions / jour',<br>`lib/pages/legal_info_page.dart:242` — • de vous (création de compte, annonces, messages)<br>`lib/pages/legal_info_page.dart:355` — subtitle: "Création de compte, responsabilités, accès.",<br>`lib/pages/legal_info_page.dart:361` — 1. Création de compte | Décrire les conditions pour créer/utiliser un compte. |
| Âge minimum | ❌ Manquant probable | Aucune preuve trouvée automatiquement | Préciser l’âge minimum ou l’obligation d’être majeur/autorisé. |
| Compte personnel | ✅ OK probable | `lib/pages/account_page.dart:134` — String _profileAccountType = 'Particulier';<br>`lib/pages/account_page.dart:838` — _profileAccountType = 'Particulier';<br>`lib/pages/account_page.dart:1563` — loadedAccountType.isNotEmpty ? loadedAccountType : 'Particulier';<br>`lib/pages/account_page.dart:1586` — _profileAccountType = 'Particulier';<br>`lib/pages/account_page.dart:3482` — // ── Default (Particulier) header ─────────────────────────────────────────── | Définir l’usage d’un compte personnel/particulier. |
| Compte professionnel | ✅ OK probable | `lib/widgets/account_profile_sections.dart:693` — 'Vous êtes une entreprise ?',<br>`lib/dev/page_capture_catalog_page.dart:295` — description: 'Création et édition du profil professionnel.',<br>`lib/dev/page_capture_catalog_page.dart:332` — description: 'Parcours IA — création d\'entreprise guidée.',<br>`lib/config/ai_prompts.dart:116` — - Sois persuasif et professionnel<br>`lib/config/ai_prompts.dart:127` — 'Transforme cette transcription en annonce professionnelle:\n\n{transcript}\n\nCatégorie: {category}\nVille: {city}'; | Définir l’usage d’un compte professionnel et les obligations pro éventuelles. |
| Compte vérifié par téléphone | ❌ Manquant probable | Aucune preuve trouvée automatiquement | Expliquer ce que signifie un compte vérifié par téléphone et ses limites. |
| Règles de publication | ✅ OK probable | `lib/services/marketplace_publish_service.dart:476` — 'La ville est obligatoire pour publier une annonce marketplace.');<br>`lib/pages/consult_offers_page.dart:2877` — 'La modification d\'annonce doit passer par le flux canonique Marketplace. Cette edition directe n\'est plus autorisee ici.',<br>`lib/pages/legal_info_page.dart:419` — L’utilisateur s’engage à publier une annonce claire, utile et suffisamment détaillée (besoin, lieu/zone, budget indicatif si possible, contraintes éventuelles). | Lister les règles de rédaction et de publication d’une annonce. |
| Annonces interdites | 🟡 À vérifier / partiel | `lib/pages/legal_info_page.dart:407` — 2. Contenus interdits (liste indicative) | Lister les catégories d’annonces interdites. |
| Produits ou services interdits | ✅ OK probable | `lib/services/notification_service.dart:405` — Future<void> clearMessagingPermissionPromptDismissed(String userId) async {<br>`lib/pages/legal_info_page.dart:380` — • de contenus manifestement illicites,<br>`lib/pages/legal_info_page.dart:409` — • annonces illégales (stupéfiants, contrefaçons, armes, etc.),<br>`lib/pages/home_page.dart:568` — .clearMessagingPermissionPromptDismissed(user.uid); | Interdire les produits/services illégaux, dangereux, réglementés ou contraires aux règles. |
| Modération possible | ✅ OK probable | `lib/main.dart:403` — final moderationStatus = (data['moderationStatus'] ?? '').toString().trim();<br>`lib/main.dart:454` — moderationStatus: moderationStatus,<br>`lib/dev/page_capture_catalog_page.dart:379` — description: 'Modération photos — swipe validation.',<br>`lib/pages/admin_space_page.dart:231` — title: 'Qualité & modération',<br>`lib/pages/admin_space_page.dart:236` — 'Temps moyen de modération', | Dire que la plateforme peut contrôler/modérer certains contenus. |
| Suspension de compte | ✅ OK probable | `lib/pages/legal_info_page.dart:377` — L’Éditeur se réserve le droit de suspendre ou supprimer un compte, sans préavis, en cas notamment :<br>`lib/pages/legal_info_page.dart:427` — • suspendre le compte en cas d’abus répété. | Prévoir les cas de suspension temporaire ou définitive. |
| Suppression de contenu | ✅ OK probable | `lib/pages/legal_info_page.dart:424` — • masquer, retirer ou désactiver une annonce,<br>`lib/pages/user_offers_section.dart:3296` — ? 'Suppression refusée. Cette annonce n’est pas reconnue comme vous appartenant.' | Prévoir la suppression/retrait d’annonces ou messages non conformes. |
| Signalement | ✅ OK probable | `lib/pages/admin_space_page.dart:237` — 'Nombre de signalements utilisateurs',<br>`lib/pages/admin_space_page.dart:1284` — label: 'Signalements',<br>`lib/pages/admin_space_page.dart:1299` — trendLabel: 'Signalements / jour',<br>`lib/pages/legal_info_page.dart:395` — subtitle: "Contenus autorisés, modération, signalements.",<br>`lib/pages/legal_info_page.dart:429` — La modération peut être effectuée automatiquement ou manuellement, notamment suite à un signalement. | Expliquer comment signaler une annonce, un message ou un utilisateur. |
| Blocage utilisateur | ❌ Manquant probable | Aucune preuve trouvée automatiquement | Prévoir la possibilité de bloquer un utilisateur. |
| Messagerie interne | ✅ OK probable | `lib/main.dart:22` — import 'pages/messages/messages_page_v2.dart';<br>`lib/main.dart:976` — if (target.routeName == AppDeepLinkTarget.messagesRouteName //<br>`lib/main.dart:977` — target.routeName == AppDeepLinkTarget.messagesV2RouteName) {<br>`lib/main.dart:980` — builder: (_) => MessagesPageV2(<br>`lib/main.dart:981` — initialConversationId: target.conversationId, | Expliquer l’usage de la messagerie interne. |
| Notifications | ✅ OK probable | `lib/main.dart:607` — /// Initialise les services non requis pour le premier rendu (notifications<br>`lib/main.dart:611` — // Notifications push (toutes plateformes). Sur Web, l'enregistrement du token<br>`lib/main.dart:614` — await NotificationService().initialize(<br>`lib/main.dart:618` — area: 'notifications',<br>`lib/main.dart:622` — adminWebDebugStore.recordError('notifications', e, message: 'init-failed'); | Expliquer que l’utilisateur peut recevoir des notifications liées au service. |
| Responsabilité en cas de litige entre utilisateurs | 🟡 À vérifier / partiel | `lib/pages/offers/widgets/payment_info_popup.dart:159` — 'Privilégiez toujours un paiement traçable pour protéger le client comme le prestataire en cas de litige.', | Dire que les litiges liés aux prestations se règlent entre utilisateurs. |
| Limites de responsabilité de la plateforme | ❌ Manquant probable | Aucune preuve trouvée automatiquement | Limiter la responsabilité d’ilipresto pour les contenus, prestations, paiements, litiges et disponibilité. |
| Droit applicable | ❌ Manquant probable | Aucune preuve trouvée automatiquement | Indiquer le droit applicable aux CGU. |
| Tribunal compétent si applicable | ❌ Manquant probable | Aucune preuve trouvée automatiquement | Ajouter la clause de compétence si elle est adaptée juridiquement. |
| Modification des CGU | 🟡 À vérifier / partiel | `lib/pages/legal_info_page.dart:345` — Modification des CGU | Prévoir que les CGU peuvent être modifiées et comment l’utilisateur est informé. |

## Blocs à compléter en priorité

- ❌ Manquant probable **ilipresto n’est pas employeur** : Préciser explicitement qu’ilipresto n’est pas employeur des utilisateurs/prestataires.
- ❌ Manquant probable **ilipresto n’est pas mandataire de paiement entre particuliers** : Dire qu’ilipresto n’agit pas comme mandataire ou intermédiaire de paiement entre particuliers.
- ❌ Manquant probable **Âge minimum** : Préciser l’âge minimum ou l’obligation d’être majeur/autorisé.
- ❌ Manquant probable **Compte vérifié par téléphone** : Expliquer ce que signifie un compte vérifié par téléphone et ses limites.
- 🟡 À vérifier / partiel **Annonces interdites** : Lister les catégories d’annonces interdites.
- ❌ Manquant probable **Blocage utilisateur** : Prévoir la possibilité de bloquer un utilisateur.
- 🟡 À vérifier / partiel **Responsabilité en cas de litige entre utilisateurs** : Dire que les litiges liés aux prestations se règlent entre utilisateurs.
- ❌ Manquant probable **Limites de responsabilité de la plateforme** : Limiter la responsabilité d’ilipresto pour les contenus, prestations, paiements, litiges et disponibilité.
- ❌ Manquant probable **Droit applicable** : Indiquer le droit applicable aux CGU.
- ❌ Manquant probable **Tribunal compétent si applicable** : Ajouter la clause de compétence si elle est adaptée juridiquement.
- 🟡 À vérifier / partiel **Modification des CGU** : Prévoir que les CGU peuvent être modifiées et comment l’utilisateur est informé.

## Commandes utiles après correction

```bash
flutter analyze --no-fatal-infos
flutter build web --release --no-wasm-dry-run
```
