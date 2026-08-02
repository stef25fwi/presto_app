# Périmètre de lancement iliprestō

## Statut du document

- Version : 1.0
- Date d’approbation : 2026-08-02
- Statut : approuvé pour le programme de préparation au lancement
- Version cible initiale : bêta gratuite publique
- Domaine de référence : `https://ilipresto.fr`

## 1. Objectif de la release

La première release publique doit démontrer qu’iliprestō permet une mise en relation locale utile, sûre et mesurable entre une personne qui recherche un service et une personne susceptible d’y répondre.

Cette release n’a pas pour objectif de maximiser immédiatement les revenus. Elle doit d’abord :

- rendre les parcours principaux réellement utilisables ;
- confirmer la qualité de la marketplace et de la messagerie ;
- mesurer la liquidité locale et les coûts ;
- sécuriser les contenus, comptes et opérations administratives ;
- fournir les bases de la future activation commerciale ;
- rester réversible et observable.

## 2. Portée géographique

- iliprestō est accessible et présenté comme un service national ;
- la communication et l’acquisition peuvent cibler initialement la Guadeloupe, la Martinique et la Caraïbe française ;
- aucune règle générale ne doit exclure un utilisateur situé dans une autre région française lorsque le service est techniquement disponible ;
- les contenus ultramarins ou régionaux restent contextualisés dans les pages et parcours concernés ;
- les métadonnées SEO générales, les stores et les documents produit ne présentent pas iliprestō comme une plateforme exclusivement ultramarine.

## 3. Mode d’exploitation au lancement

La release initiale utilise le mode `free_beta`.

| Fonction | État de lancement |
|---|---|
| Accès au service | Gratuit selon les droits et limites de sécurité |
| Abonnements visibles | Non |
| Checkout Stripe utilisateur | Non |
| Commission sur les prestations | 0 % |
| Paiement du service entre utilisateurs | Hors plateforme |
| Documents légaux | Versions bêta gratuite validées |
| Activation commerciale | Interdite sans décision go/no-go distincte |

Le mode commercial est techniquement préparé mais ne fait pas partie du périmètre actif de la première release publique.

## 4. Plateformes

### Web

La Web App sur `ilipresto.fr` est la surface prioritaire et doit être certifiée pour le lancement :

- chargement et démarrage fiables ;
- authentification Web ;
- routes publiques et légales accessibles directement ;
- responsive sur les largeurs prévues ;
- référencement et page de pré-lancement sans double rendu ;
- surveillance, artefact de release et rollback.

### Android

Android fait partie du produit cible, mais sa publication publique reste conditionnée au point 16 :

- AAB release reproductible ;
- Play App Signing et empreintes Firebase ;
- Play Integrity et App Check ;
- notifications sur appareil réel ;
- déclarations Play Console ;
- test fermé et rapport de pré-lancement ;
- décision de paiement mobile conforme.

Une bêta Web peut être prête avant la publication Android, mais le programme global 18/18 n’est terminé qu’après certification mobile.

### iOS

iOS reste dans le produit multiplateforme. La publication nécessite :

- build signé dans l’environnement Apple prévu ;
- identifiants, capabilities et notifications vérifiés ;
- Sign in with Apple lorsque requis ;
- politique de paiement conforme ;
- métadonnées, confidentialité et tests appareils.

## 5. Fonctions incluses dans la bêta publique

### 5.1 Pages publiques et acquisition

- page de pré-lancement contrôlée ;
- accès public aux mentions légales, CGU, confidentialité et suppression de compte ;
- métadonnées SEO nationales ;
- redirection vers le domaine canonique ;
- présentation claire de la plateforme, de l’IA et du 0 % de commission.

### 5.2 Comptes

- inscription et connexion email ;
- vérification d’email ;
- récupération et changement de mot de passe ;
- connexion Google sur les plateformes certifiées ;
- connexion Apple sur les plateformes concernées ;
- profil utilisateur ;
- changement d’email selon les règles de réauthentification ;
- demande de suppression de compte ;
- consentement aux versions légales applicables ;
- déconnexion et gestion correcte des sessions.

### 5.3 Marketplace

- création d’un brouillon ;
- saisie manuelle ou assistance IA ;
- ajout des médias autorisés ;
- validation et soumission côté backend ;
- modération et statut observable ;
- consultation, recherche et filtres ;
- favoris ;
- affichage du contact lorsque les règles l’autorisent ;
- clôture et suppression ;
- signalement ;
- avis vérifiés et modération des avis.

### 5.4 Messagerie

- création ou réutilisation d’une conversation liée à une annonce ;
- messages texte ;
- photos, fichiers et audios autorisés ;
- affichage plein écran des médias prévu ;
- watermark lorsque requis ;
- confirmation avant suppression ;
- lecture, archivage, blocage et déblocage ;
- signalement ;
- notifications et rappels autorisés ;
- pagination et nettoyage selon la politique de conservation.

### 5.5 IA

- brouillon d’annonce par texte ;
- transcription et extraction à partir de la voix ;
- résultat structuré ;
- validation humaine obligatoire ;
- limites de taille et de durée ;
- App Check et authentification selon le risque ;
- idempotence, retry, timeout et fallback ;
- métriques de succès, latence et coût ;
- rétention limitée des données opérationnelles ;
- rollback Remote Config documenté.

### 5.6 « Je me lance »

- collecte de la région, du statut et de l’activité ;
- génération d’un parcours personnalisé ;
- étapes guidées ;
- avertissements liés au statut ;
- démarches, documents, coûts et ressources ;
- liens cliquables ;
- listes longues repliables ;
- suivi de progression ;
- sauvegardes et export selon droits ;
- logo et filigrane sur les PDF concernés.

### 5.7 Administration, support et modération

- gestion des utilisateurs et des rôles autorisés ;
- gestion des annonces et médias ;
- traitement des signalements ;
- modération des avis ;
- support ;
- configuration des modes d’exploitation ;
- configuration des fonctions IA ;
- journaux d’audit ;
- statistiques nécessaires à l’exploitation ;
- historique des actions sensibles.

### 5.8 Qualité et exploitation

- analyse statique ;
- tests Flutter et Functions ;
- tests des règles Firebase ;
- couverture mesurée ;
- CodeQL ;
- build Web release ;
- contrôle de taille du bundle ;
- artefact de restauration ;
- déploiement automatisé ;
- smoke tests ;
- Crashlytics, Performance et journaux structurés selon plateforme ;
- alertes de coûts et incidents prévues.

## 6. Fonctions exclues de la release initiale

Les éléments suivants ne sont pas nécessaires à la bêta gratuite publique ou restent explicitement hors produit :

- abonnement payant obligatoire ;
- activation de Stripe en production pour les utilisateurs ;
- encaissement du paiement des prestations ;
- séquestre, portefeuille ou transfert d’argent entre utilisateurs ;
- commission sur le montant des services ;
- garantie de réalisation ou de résultat ;
- assurance automatique des prestations ;
- relation employeur-salarié organisée par iliprestō ;
- contrôle exhaustif automatique des antécédents ;
- publication automatique d’un contenu IA sans validation ;
- conseil juridique, fiscal ou social définitif ;
- promesse publique d’une réponse en moins de 10 minutes sans preuve KPI ;
- expansion marketing nationale payante avant validation des premières zones ;
- activation d’une fonctionnalité non observable ou non réversible.

## 7. Critères d’entrée en recette finale

Une release candidate peut entrer en recette finale lorsque :

1. les parcours critiques sont implantés ;
2. les migrations requises sont identifiées et testées ;
3. les tests de non-régression passent ;
4. les règles Firebase sont testées dans l’émulateur ;
5. les dépendances bloquantes sont traitées ou font l’objet d’une décision documentée ;
6. aucune dette P0 non acceptée ne reste ouverte ;
7. les documents légaux du mode actif sont complets ;
8. les environnements et secrets sont inventoriés ;
9. le plan de rollback existe ;
10. le support et les contacts d’incident sont identifiés.

## 8. Critères go/no-go de la bêta publique

La décision « go » exige au minimum :

### Produit

- publication d’annonce de bout en bout ;
- recherche et consultation sans erreur bloquante ;
- conversation réciproque fonctionnelle ;
- signalement et modération opérationnels ;
- parcours « Je me lance » exploitable ;
- textes publics cohérents avec le mode bêta.

### Sécurité

- aucun secret privé dans le dépôt ou le client ;
- élévation de rôle impossible côté client ;
- règles Firestore et Storage validées ;
- App Check configuré selon le plan de déploiement ;
- suppression de compte et traitement RGPD vérifiés ;
- contrôles de sécurité obligatoires du périmètre de lancement documentés.

### Qualité

- analyse Flutter sans erreur bloquante ;
- tests critiques verts ;
- Functions compilées et testées ;
- build Web release réussi ;
- smoke tests de production réussis ;
- aucune régression P0 ou P1 ouverte ;
- performances et accessibilité des parcours principaux contrôlées.

### Exploitation

- déploiement reproductible ;
- artefact de rollback disponible ;
- monitoring et alertes actifs ;
- support prêt ;
- budget et alertes de coûts configurés ;
- décision go/no-go enregistrée.

Le programme séquentiel ajoute une exigence plus stricte : le point 18 ne peut être validé que lorsque les points 1 à 17 sont déjà `verified`.

## 9. Critères d’arrêt ou de rollback

Le lancement est suspendu ou la release est retirée lorsque l’un des événements suivants est confirmé :

- impossibilité généralisée de créer un compte ou de se connecter ;
- publication ou messagerie indisponible sur une part importante des utilisateurs ;
- fuite ou exposition non autorisée de données ;
- contournement des rôles ou règles d’accès ;
- paiements ou abonnements activés par erreur en bêta ;
- taux de crash ou d’erreur dépassant le seuil accepté ;
- coût incontrôlé sans capacité de coupure ;
- modération indisponible face à un abus sérieux ;
- corruption ou perte de données ;
- problème légal rendant la publication non conforme.

Le rollback doit préciser :

- la version cible de retour ;
- les données ou migrations concernées ;
- les fonctions à désactiver par Remote Config ;
- les personnes habilitées ;
- le message utilisateur ;
- la méthode de vérification après retour.

## 10. Phases après la bêta

### Phase de stabilisation

- corriger les défauts observés ;
- améliorer la liquidité des zones prioritaires ;
- confirmer les KPI de rétention et de coût ;
- finaliser les stores ;
- renforcer l’accessibilité et les performances.

### Préparation commerciale

- finaliser l’identité juridique commerciale ;
- vérifier les offres, prix et droits ;
- tester Stripe avec un compte Firebase réel ;
- décider la politique de paiement mobile ;
- mettre à jour les documents et consentements ;
- vérifier la marge brute ;
- enregistrer un go/no-go commercial distinct.

### Extension géographique

Une nouvelle zone est activement promue lorsque :

- un minimum d’offre et de demande est identifié ;
- les catégories prioritaires sont couvertes ;
- le support et la modération peuvent suivre ;
- les métriques de la zone sont séparables ;
- les contenus régionaux sont exacts ;
- l’acquisition ne dégrade pas la qualité des zones existantes.

## 11. Matrice d’acceptation de la release

| Domaine | Propriétaire | Preuve minimale |
|---|---|---|
| Produit | Product owner | Exigences, business model, KPI et périmètre approuvés |
| UX/accessibilité | Produit + qualité | Matrice responsive et audit accessibilité |
| Architecture | Référent technique | Audit, dette P0 close et flux documentés |
| Sécurité | Référent sécurité | Registres et preuves externes validés |
| Marketplace | Produit + backend | Tests E2E et preuves des règles métier |
| Messagerie | Produit + backend | Tests des médias, droits, suppression et push |
| IA | Produit + IA/backend | Évaluation, smoke, métriques et rollback |
| Paiement | Produit + finance/technique | Registre Stripe, test réel et politique stores |
| Légal/RGPD | Éditeur | Documents, identité, suppression et conservation |
| Exploitation | Responsable release | CI/CD, monitoring, rollback, support et budget |

## 12. Décision de périmètre

La release de référence est donc une bêta gratuite nationale, prioritairement lancée et mesurée dans les premières zones de la Caraïbe française, comprenant les parcours complets de mise en relation, IA, messagerie, confiance, administration et création d’activité, sans paiement des prestations ni commission.

Toute fonction non mentionnée comme incluse est considérée optionnelle tant qu’elle ne devient pas une dépendance d’un parcours critique ou une obligation légale.
