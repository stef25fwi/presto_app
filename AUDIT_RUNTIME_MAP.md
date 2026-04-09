# AUDIT RUNTIME MAP

Date: 2026-04-09

Objectif de ce rapport:
- cartographier les ecrans, routes, actions et services critiques sans refactor massif
- distinguer actif, legacy et douteux
- preparer une remise a niveau PROD par petites etapes compilables

## Resume executif

Etat general:
- coeur applicatif actif concentre majoritairement dans lib/main.dart
- navigation principale stable sur 5 tabs mais trop couplee a du code inline
- coexistence de flux actifs et de prototypes/maquettes dans lib/pages et lib/
- base Firebase deja fonctionnelle, mais l'ordre d'initialisation et les diagnostics restent des zones critiques

Notation interne:
- ACTIF: ecran ou service branche dans le flux courant
- ACTIF_SECONDAIRE: reachable mais hors parcours principal ou selon etat utilisateur
- LEGACY: prototype/ancienne version explicitement non prioritaire
- DOUTEUX: reachable ou reference indirecte, necessite validation manuelle avant suppression

## Cartographie des pages

| Statut | Ecran | Fichier | Acces principal | Notes |
| --- | --- | --- | --- | --- |
| ACTIF | SplashScreen | lib/main.dart | ecran initial | gere redirect Google Sign-In web et bootstrap |
| ACTIF | HomePage | lib/main.dart | root app | orchestre bottom nav, hero, categories, notifications |
| ACTIF | ConsultOffersPage | lib/main.dart | bottom nav index 1 | lecture listings + offers legacy fusionnes |
| ACTIF | PublishOfferPage | lib/main.dart | bottom nav index 2, route /publish | publication marketplace active |
| ACTIF | MessagesPageV2 | lib/pages/messages/messages_page_v2.dart | bottom nav index 3, /messages, /messages-2, deep links | point d'entree messagerie active |
| ACTIF | AccountPage | lib/main.dart | bottom nav index 4, route /account | profil, auth, admin gate |
| ACTIF | OfferDeepLinkPage | lib/main.dart | /offers/{id}, /listings/{id} | resolution deep links vers detail actif |
| ACTIF | OfferDetailsPage | lib/pages/offers/offer_details_page.dart | detail annonce depuis home, favoris, deep links | detail prod actuel |
| ACTIF_SECONDAIRE | ProfilePage | lib/profile_page.dart | fallback compte si utilisateur non connecte | flux auth/profil parallele mais encore branche |
| ACTIF_SECONDAIRE | ProProfilePage | lib/pages/pro_profile_page.dart | depuis ProfilePage | parcours pro secondaire |
| ACTIF_SECONDAIRE | UserPublicProfilePage | lib/main.dart | depuis detail/messages selon contexte | pas de route nommee directe visible |
| ACTIF_SECONDAIRE | LegalInfoPage | lib/pages/legal_info_page.dart | depuis accueil | ecran informationnel |
| ACTIF_SECONDAIRE | ToolboxHubPage | lib/pages/toolbox_hub_page.dart | route nommee + slide accueil | hub outils entrepreneur |
| ACTIF_SECONDAIRE | CurrentToolboxPage | lib/pages/toolbox_hub_page.dart | depuis ToolboxHubPage, route nommee | renvoie vers parcours en cours |
| ACTIF_SECONDAIRE | ToolboxJeMeLancePage | lib/pages/toolbox_je_me_lance_page.dart | via hub/current toolbox | gros flux outil entrepreneur |
| ACTIF_SECONDAIRE | EntrepreneurCalculatorPage | lib/pages/pricing_calculator_page.dart | route nommee, toolbox | calculateur actif |
| ACTIF_SECONDAIRE | AdminSpacePage | lib/pages/admin_space_page.dart | depuis compte si droits admin | surface critique mais conditionnelle |
| DOUTEUX | EntrepreneurToolboxPage | lib/pages/entrepreneur_toolbox_page.dart | alias direct vers ToolboxJeMeLancePage | faible complexite, garder jusqu'a validation des usages |

## Cartographie navigation

Navigation principale:
- bottom nav dans HomePage: Accueil, Je consulte, Publier une offre, Messages, Compte
- routes nommees explicites: /publish, /messages, /messages-2, /account, /toolbox_hub, /toolbox_current, /entrepreneur_calculator
- deep links geres par onGenerateRoute + parseAppDeepLink: /messages/{conversationId}, /messages-2/{conversationId}, /chat/{conversationId}, /offers/{offerId}, /listings/{offerId}

Destinations verifiees comme actives:
- offer detail via OfferDeepLinkPage puis OfferDetailsPage
- messages via MessagesPageV2
- admin via AccountPage si droits admin resolves
- toolbox via AppRoutes et cartes hub

Chemins morts ou suspects:
- route /auth commentee dans lib/main.dart: code dormant, pas expose comme route active
- double route /messages et /messages-2: backward compatibility acceptable mais dette a clarifier
- UserPublicProfilePage sans route nommee publique explicite: reachable surtout par navigation imperative

## Cartographie actions et boutons

Actions critiques actives verifiees:
- navigation bottom nav
- ouverture detail annonce
- publication annonce
- favoris depuis detail et compte
- messagerie depuis detail
- ouverture de routes depuis notifications
- signalement annonce marketplace

Actions non branchees ou a surveiller:
- route /auth commentee: dette a nettoyer ou a reintroduire proprement

Actions actives mais fragiles:
- ouverture messages depuis detail: depend de ensureConversation + etat auth
- publication: depend auth, App Check, Storage, Cloud Functions, Firestore
- notifications: click avant navigator pret gere via pending route, mais ordre d'init reste sensible
- lecture offres publiques: fusion listings/offers legacy, indexes et App Check a surveiller

## Services critiques et dependances Firebase

Bootstrap critique:
- lib/firebase_init.dart: point central init Firebase
- lib/main.dart: App Check, Crashlytics, notifications, CitySearch, runApp

Services critiques:
- lib/services/notification_service.dart: FCM, local notifications, route opening
- lib/services/marketplace_publish_service.dart: publication annonce
- lib/services/conversation_service.dart: creation/reprise conversation
- lib/services/admin_access_resolver.dart: gate admin
- lib/services/firebase_functions_region.dart: region functions
- lib/services/inbox_counts.dart: badges messagerie

Points fragiles releves:
- main.dart reste trop gros et concentre bootstrap + pages + logique metier
- coexistence listings / offers legacy dans les lectures publiques
- App Check critique pour micro IA et lecture backend selon environnement
- notifications dependantes du moment ou navigatorKey devient disponible
- profil non connecte renvoie encore vers un flux profile_page.dart parallele au compte principal

Verifications ciblees supplementaires:
- la page Messagerie ne depend pas uniquement de participants array-contains: elle fusionne aussi un fallback notifications et un fallback messages deja demarres via lib/pages/messages/conversations_list_page.dart
- une conversation reste visible si elle appartient bien a l'utilisateur et si un contenu rendable minimal existe (message, date, titre offre ou nom correspondant)
- les routes secondaires toolbox sont conservees comme ACTIF_SECONDAIRE et extraites hors de la table principale de lib/main.dart pour limiter le couplage

## Zones stables, critiques, legacy

Zones stables:
- parser de deep links messages/offers dans lib/services/app_route_parser.dart
- initialisation Firebase centralisee dans lib/firebase_init.dart
- messagerie v2 comme point d'entree principal
- diagnostic de lecture des annonces publiques extrait dans lib/features/offers/public_offers_read_diagnostics.dart

Zones critiques:
- lib/main.dart
- lib/pages/offers/offer_details_page.dart
- lib/services/notification_service.dart
- lib/services/marketplace_publish_service.dart
- flux admin conditionnel

Zones legacy:
- anciennes pages legacy supprimees le 2026-04-09: publish_offer_page.dart, offer_detail_v2_top.dart, offer_detail_v2_page.dart, premium_ai_button_preview.dart

## Phases de remise a niveau proposees

### Phase 1 - cartographie et securisation
- conserver le comportement metier
- ajouter des logs debug-only sur navigation, publication, favoris, messagerie, notifications
- documenter actif/legacy/douteux
- ne supprimer aucun ecran sans preuve d'inutilisation

### Phase 2 - reparation des chemins casses et des faux signaux
- corriger les erreurs affichees comme succes
- corriger les boutons silencieux seulement sur parcours actifs
- fiabiliser mounted/context sur les flux async sensibles
- clarifier les messages d'erreur auth / Firestore / App Check / reseau

### Phase 3 - remise a niveau architecture prod
- extraire progressivement hors de lib/main.dart les blocs a plus forte cohesion
- commencer par utilitaires transverses, diagnostics et ecrans/profil detail bien delimites
- etiqueter le legacy avec commentaires explicites et supprimer seulement apres validation des usages

## Correctifs appliques pendant cet audit

Phase 1:
- ajout d'un logger runtime debug-only central: lib/utils/runtime_action_logger.dart
- instrumentation des parcours critiques dans lib/main.dart, lib/pages/offers/offer_details_page.dart et lib/services/notification_service.dart

Phase 2:
- correction d'un faux message de succes sur erreur lors du retrait de favori dans lib/main.dart
- correction des faux snacks de succes en erreur dans lib/pages/admin_space_page.dart
- correction des faux snacks de succes en erreur dans lib/pages/publish_offer_page.dart

Phase 3 initiale:
- debut d'extraction hors lib/main.dart avec un utilitaire runtime dedie
- extraction des diagnostics de lecture offres publiques vers lib/features/offers/public_offers_read_diagnostics.dart
- marquage explicite LEGACY/LEGACY_TEMPLATE/LEGACY_PREVIEW sur les fichiers non prod les plus evidents puis suppression de quatre ecrans legacy non references
- extraction des routes nommees secondaires toolbox vers lib/app/secondary_named_routes.dart

## Passe de suivi 2026-04-09

Checklist etat reel apres nouvelle passe:

### Etape A - cartographie et securisation
- OK: cartographie des ecrans, routes, zones legacy, zones critiques et services critiques documentee dans ce fichier
- OK: logs debug-only centralises via lib/utils/runtime_action_logger.dart et branches sur navigation, favoris, messagerie, publication, detail annonce et notifications
- OK: initialisation Firebase centralisee via lib/firebase_init.dart pour l'app et le handler de notifications background
- PARTIEL: le cablage Firebase mobile est plus explicite, mais lib/firebase_options.dart fonctionne encore avec des valeurs de fallback tant que google-services.json et GoogleService-Info.plist ne sont pas fournis

### Etape B - boutons, chemins, erreurs, async
- OK: faux messages de succes remplaces par des erreurs honnetes sur les flux admin, publication legacy, profil pro et retrait de favoris
- OK: bouton d'alerte decoratif sur le detail annonce remplace par un comportement honnete avec log + snackbar
- OK: puce Admin decorative rendue inertie proprement au lieu d'un callback vide
- OK: navigation notifications durcie avec attente explicite du navigator, file d'attente de route et de-duplication des ouvertures recentes
- OK: page Messagerie ne masque plus une conversation valide uniquement a cause d'un apercu incomplet; des labels fallback sont fournis
- PARTIEL: les parcours critiques sont mieux traces et mieux proteges apres await, mais la validation runtime complete des parcours reste a faire manuellement

### Etape C - extraction progressive et clarification architecture
- PARTIEL: lib/main.dart a ete allegi par petites extractions, mais reste la plus grosse zone de risque et de couplage
- OK: extraction du fallback compte non connecte vers lib/features/account/signed_out_account_fallback.dart
- OK: extraction des routes nommees secondaires toolbox vers lib/app/secondary_named_routes.dart
- OK: clarification ACTIVE / LEGACY / ACTIF_SECONDAIRE / LEGACY_TEMPLATE sur plusieurs fichiers non centraux
- PARTIEL: la logique metier reste encore largement concentree dans l'UI principale; le repo est plus lisible mais pas encore au niveau cible 10/10

Correctifs confirmes dans le code:
- centralisation de Firebase init et reutilisation sur le bootstrap principal et le background messaging
- diagnostics plus honnetes pour les lectures publiques d'annonces, avec debug card en mode debug
- lecture publique listings-first avec backfill legacy borne et explicite
- robustesse accrue du routage push au demarrage
- visibilite de conversations preservee meme en cas de metadonnees d'aperçu partielles
- desactivation honnete de plusieurs actions decoratives au lieu d'un silence UI
- documentation des zones legacy pour eviter une suppression prematuree
- suppression de quatre ecrans legacy non references: publish_offer_page.dart, offer_detail_v2_top.dart, offer_detail_v2_page.dart, premium_ai_button_preview.dart

Risques residuels apres cette passe:
- lib/main.dart reste trop gros et melange bootstrap, navigation, ecrans, UI et logique metier
- le projet mobile n'embarque toujours pas les fichiers natifs Firebase officiels; les options de fallback maintiennent la compilation mais ne remplacent pas une configuration FlutterFire definitive
- les lectures publiques reposent encore sur une coexistence listings + offers legacy, meme si elle est maintenant bornee et mieux diagnostiquee
- le flux profile_page.dart reste un fallback secondaire encore reachable et devra etre revalide avant suppression ou fusion
- certaines validations de comportement reel n'ont pas ete executees dans cette session, notamment notifications a froid/chaud, erreurs backend simulees, et parcours admin complet

Validations manuelles encore requises avant cloture PROD:
- notifications push a chaud et a froid sur messages et offers
- lecture des annonces publiques en cas d'erreur App Check, regles Firestore ou index manquant
- parcours Publier une offre avec photos, auth, micro et erreurs reseau
- compte non connecte puis connecte, y compris le fallback SignedOutAccountFallback
- acces admin autorise / refuse sur un vrai compte
- lancement Android/iOS avec configuration Firebase native definitive

## Validations manuelles recommandees

Priorite haute:
- bottom nav complet sur mobile et web
- consulter offres publiques avec et sans session utilisateur
- publier une offre avec et sans photos
- detail annonce: message, favori, partage, signalement
- notification push ouverte a froid et a chaud
- compte non connecte puis connecte
- acces admin avec compte autorise et compte non autorise

Priorite moyenne:
- deep links /offers/{id}, /listings/{id}, /messages/{conversationId}
- toolbox hub et calculateur entrepreneur
- profil pro secondaire

## Prochaines suppressions candidates uniquement apres validation

- lib/pages/toolbox_page.dart
- lib/pages/entrepreneur_toolbox_page.dart
- lib/profile_page.dart
- wrapper MessagesPage dans lib/main.dart

Condition stricte avant suppression:
- zero usage runtime confirme
- zero import fonctionnel confirme
- validation manuelle des parcours equivalents actifs