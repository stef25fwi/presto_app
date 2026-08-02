# Inventaire des composants interactifs — point 2

## Objectif

Recenser les composants qui ne bénéficient pas automatiquement des garanties du thème Material central. Chaque ligne doit être vérifiée pour la taille tactile, le focus clavier, la sémantique, le contraste et le comportement avec texte agrandi.

## Priorité P0 — parcours publics et critiques

| Fichier | Interaction repérée | Risque principal | Action attendue |
|---|---|---|---|
| `lib/pages/public_prelaunch_page.dart` | `GestureDetector` sur la carte « ouverture prochaine » | accès clavier, focus, ancien fond beige local | remplacer ou envelopper par interaction focusable, supprimer les couleurs beiges locales, ajouter tests clavier et responsive |
| `lib/pages/home_page.dart` | interactions personnalisées de l’accueil | ordre de focus, zones compactes, responsive | audit widget par widget sur 320 à 1440 px |
| `lib/widgets/home_interactions.dart` | zones cliquables personnalisées | cible tactile et sémantique | mesurer et ajouter `Semantics`/`InkWell` lorsque nécessaire |
| `lib/widgets/home_bottom_nav_item.dart` | navigation basse personnalisée | taille tactile, état sélectionné annoncé | vérifier 48 px, rôle bouton et état sélectionné |
| `lib/pages/publish_offer_page.dart` | publication et actions Micro IA | boutons compacts, progression et erreurs | vérifier focus, labels, états loading/error et texte 200 % |
| `lib/widgets/ai_publish_control.dart` | contrôles de publication IA | sémantique et activation clavier | vérifier libellés, focus, désactivation et états |
| `lib/pages/messages/conversation_thread_page.dart` | médias et actions de conversation | gestes non annoncés, suppression, plein écran | vérifier semantics, tooltips, clavier et confirmations |
| `lib/pages/messages/conversations_list_page.dart` | lignes et actions de conversations | cible tactile et état non lu | vérifier taille, annonce du statut et ordre de focus |

## Priorité P1 — compte, offres et parcours guidé

| Fichier | Interaction repérée | Risque principal | Action attendue |
|---|---|---|---|
| `lib/pages/account_page.dart` | sections et actions de compte | ordre de focus, actions destructrices | vérifier confirmation, libellés et contraste |
| `lib/pages/offers/offer_details_page.dart` | contact, favoris et médias | actions iconiques, zones tactiles | vérifier tooltips et 48 px |
| `lib/pages/consult_offers_page.dart` | filtres, cartes et pagination | overflow et navigation clavier | tester largeurs et texte agrandi |
| `lib/pages/fiche_pro_page.dart` | profil et actions | sémantique des cartes | vérifier titres, boutons et contenus dynamiques |
| `lib/pages/toolbox_je_me_lance_page.dart` | étapes, accordéons et liens | focus, expansion annoncée, texte long | tester clavier et lecteur d’écran |
| `lib/widgets/entrepreneur_toolbox_slide.dart` | slide promotionnel interactif | geste seul et contraste | fournir action explicite et sémantique |
| `lib/widgets/premium_info_button.dart` | action informative compacte | cible tactile | imposer 48 px et tooltip |
| `lib/widgets/hero_media_slider.dart` | carrousel média | gestes, pagination et alternatives | tester clavier, annonces et réduction d’animation |

## Priorité P2 — administration et outils internes

| Fichier | Interaction repérée | Risque principal | Action attendue |
|---|---|---|---|
| `lib/pages/admin_typography_page.dart` | édition typographique | champs denses | vérifier focus et erreurs |
| `lib/widgets/typography_floating_panel.dart` | panneau flottant | petite cible et recouvrement | tester 320 px et clavier |
| `lib/pages/admin_hero_slides_page.dart` | gestion de slides | drag/gestes et actions iconiques | proposer alternatives clavier |
| `lib/pages/admin/ad_placeholder_images_admin_page.dart` | médias administratifs | zones compactes | vérifier 48 px et libellés |

## Règles de correction

1. Préférer `InkWell`, `IconButton`, `TextButton`, `ListTile` ou un autre composant Material focusable à un `GestureDetector` nu.
2. Toute action iconique doit posséder un `tooltip` ou un libellé sémantique pertinent.
3. Toute zone interactive personnalisée doit mesurer au moins 48 × 48 px.
4. L’ordre de focus doit suivre l’ordre visuel et permettre de quitter les modales, menus et carrousels.
5. Les états sélectionné, développé, désactivé, en cours et en erreur doivent être exposés aux technologies d’assistance.
6. Aucun contenu essentiel ne doit dépendre exclusivement d’un geste, d’une couleur ou d’une animation.

## Définition de fini de l’inventaire

L’inventaire est terminé lorsque chaque ligne possède :

- un résultat de mesure ou de test ;
- une correction ou une justification documentée ;
- au moins un test automatisé lorsque le comportement est testable en widget test ;
- une preuve manuelle pour VoiceOver, TalkBack ou navigation clavier réelle lorsque nécessaire.
