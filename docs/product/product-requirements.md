# Exigences produit iliprestō

## Statut du document

- Propriétaire produit : éditeur d’iliprestō
- Version : 1.0
- Date d’approbation : 2026-08-02
- Statut : approuvé pour le programme de préparation au lancement
- Référence publique : `https://ilipresto.fr`

Ce document fixe le positionnement, les utilisateurs, les rôles, les parcours prioritaires et les frontières fonctionnelles d’iliprestō. Toute évolution qui contredit une décision ci-dessous doit être traitée comme un changement produit explicite, accompagné d’une mise à jour de ce document, des textes publics, des règles métier et des tests concernés.

## 1. Vision

iliprestō est une plateforme nationale de mise en relation pour les services et micro-services du quotidien. Elle permet à une personne qui exprime un besoin de trouver rapidement un particulier, un indépendant ou un professionnel disponible près de chez elle, puis d’échanger directement avec lui.

La proposition de valeur repose sur quatre principes :

1. publier ou comprendre un besoin rapidement grâce à l’assistance IA ;
2. rendre visibles l’offre et la demande à proximité ;
3. permettre un échange direct entre les utilisateurs ;
4. ne prélever aucune commission sur le montant convenu entre les utilisateurs.

Le lancement opérationnel peut être concentré en priorité sur la Guadeloupe, la Martinique et plus largement la Caraïbe française, mais le produit, ses métadonnées générales et son référencement restent nationaux. Les termes « ultramarin », « outre-mer » ou « DOM-TOM » sont réservés aux contenus régionaux réellement concernés et ne définissent jamais le marché général d’iliprestō.

## 2. Problèmes à résoudre

### Pour la personne qui cherche un service

- difficulté à identifier rapidement une personne disponible à proximité ;
- perte de temps à contacter plusieurs prestataires séparément ;
- difficulté à rédiger une demande claire ;
- manque de visibilité sur le sérieux ou l’historique des interlocuteurs ;
- besoin d’un échange simple sans intermédiaire de paiement imposé.

### Pour la personne qui propose un service

- manque de visibilité locale ;
- difficulté à détecter les demandes correspondant à ses compétences ;
- coût ou complexité de certaines plateformes traditionnelles ;
- besoin de présenter rapidement son profil, ses services et ses disponibilités ;
- besoin de conserver une relation directe avec le demandeur.

### Pour la personne qui souhaite créer une activité

- démarches perçues comme dispersées et complexes ;
- difficulté à comprendre les règles liées à son statut actuel, à son activité et à sa région ;
- manque d’un parcours guidé, progressif et exploitable ;
- besoin de liens, organismes, documents, coûts et actions regroupés par étape.

## 3. Utilisateurs et rôles produit

Les rôles produit décrivent les usages. Les rôles techniques et administratifs restent contrôlés par le backend, les règles Firebase et les custom claims.

| Rôle produit | Besoin principal | Capacités prioritaires |
|---|---|---|
| Visiteur | Comprendre la proposition de valeur et découvrir les services disponibles | Consulter les pages publiques, le référencement, les documents légaux et les contenus autorisés sans compte |
| Demandeur particulier | Publier un besoin et trouver une personne disponible | Créer une annonce, utiliser l’IA, rechercher, échanger, partager des médias, clôturer et évaluer |
| Prestataire particulier | Répondre ponctuellement à une demande locale | Décrire ses compétences, découvrir des annonces, entrer en conversation et recevoir un avis vérifié |
| Indépendant ou professionnel | Développer son activité et sa visibilité | Profil professionnel, annonces, statistiques selon offre, badge selon vérification, messagerie et outils métier |
| Créateur d’activité | Comprendre les démarches de création d’entreprise | Générer un parcours personnalisé, suivre des étapes, ouvrir les ressources et exporter selon droits |
| Modérateur | Traiter les contenus et comportements signalés | Examiner, masquer, rejeter, demander une correction et tracer les décisions |
| Administrateur | Exploiter la plateforme | Gérer utilisateurs, contenus, réglages, support, statistiques, configuration IA et paramètres publics |
| Superadministrateur | Administrer les droits et opérations à portée maximale | Attribuer les rôles autorisés, piloter les réglages sensibles et consulter les journaux d’audit |

Un même compte peut être demandeur et prestataire selon le contexte. Le produit ne force pas une séparation artificielle des comptes particuliers. Les capacités professionnelles ou administratives sont ajoutées par des droits explicites et ne peuvent pas être auto-attribuées côté client.

## 4. Parcours prioritaires

### 4.1 Découvrir et rechercher

1. l’utilisateur comprend immédiatement qu’il peut trouver ou proposer un service ;
2. il recherche par besoin, compétence, catégorie et zone ;
3. il consulte des résultats bornés et pertinents ;
4. il ouvre une annonce puis choisit un moyen de contact autorisé.

### 4.2 Publier une annonce

1. l’utilisateur décrit son besoin par texte ou par voix ;
2. l’IA propose un brouillon structuré sans publier à sa place ;
3. l’utilisateur corrige et valide les informations ;
4. les médias sont contrôlés ;
5. le backend applique validation, quotas, idempotence et modération ;
6. l’annonce prend un statut observable : brouillon, en attente, approuvée, rejetée, clôturée ou supprimée.

### 4.3 Répondre et échanger

1. un utilisateur ouvre ou réutilise une conversation liée à une annonce ;
2. il échange des messages texte et les pièces jointes autorisées ;
3. les participants peuvent archiver, bloquer, signaler ou supprimer selon les règles ;
4. les notifications respectent les préférences et les droits ;
5. les suppressions sensibles demandent une confirmation explicite.

### 4.4 Construire la confiance

1. les avis sont liés à une interaction vérifiable ;
2. les deux rôles, demandeur et prestataire, peuvent être évalués ;
3. les avis signalés passent par une modération explicite ;
4. les décisions administratives sont journalisées ;
5. une note seule ne déclenche pas automatiquement une sanction de compte.

### 4.5 Suivre « Je me lance »

1. l’utilisateur choisit sa région, son statut actuel et son activité ;
2. l’application génère un parcours personnalisé ;
3. chaque étape explique l’objectif, les vigilances, les actions, les documents et les ressources ;
4. l’utilisateur suit sa progression ;
5. les listes longues restent repliables et les liens restent cliquables ;
6. l’export PDF dépend du mode d’exploitation et des droits du compte.

### 4.6 Administrer et modérer

1. toute action sensible vérifie le rôle et la portée côté backend ;
2. les opérations destructrices demandent une confirmation ;
3. un résultat explicite est produit pour chaque élément traité ;
4. l’auteur, la date, le motif et le résultat sont journalisés ;
5. les historiques d’audit ne sont pas modifiables par le client.

## 5. Promesse fonctionnelle minimale

La version de lancement doit permettre de bout en bout :

- la création et la sécurisation d’un compte ;
- la publication d’une annonce assistée ou non par IA ;
- la consultation et la recherche d’annonces ;
- la mise en relation par messagerie ou contact autorisé ;
- la gestion des photos, fichiers et audios autorisés ;
- le signalement et la modération ;
- les notifications indispensables ;
- le parcours personnalisé de création d’activité ;
- l’administration des utilisateurs, contenus et paramètres ;
- l’accès aux documents légaux et à la suppression du compte ;
- la mesure des principaux événements produit et techniques.

## 6. Modes d’exploitation

### Bêta gratuite

Le mode initial et le mode de repli sont `free_beta`.

- la section d’abonnement est désactivée ;
- Stripe est désactivé pour l’utilisateur ;
- l’accès libre est activé pour les fonctions ouvertes pendant la bêta ;
- aucune communication ne doit présenter un abonnement comme nécessaire ;
- aucune commission n’est prélevée sur les services ;
- les limites de sécurité, d’abus, de stockage et de coûts restent applicables ;
- les documents légaux utilisent leurs versions bêta gratuite.

### Mode commercial

Le mode `commercial` ne peut être activé qu’après validation de l’identité juridique commerciale, des documents applicables, des prix, des paiements, des politiques des stores et des critères de lancement.

- la section d’abonnement devient visible ;
- Stripe peut être activé pour les parcours Web autorisés ;
- les droits sont calculés côté backend ;
- le retour navigateur ne prouve jamais un paiement ;
- les documents légaux commerciaux remplacent les documents bêta et peuvent exiger une nouvelle acceptation ;
- le principe de 0 % de commission sur la prestation entre utilisateurs est maintenu.

## 7. Positionnement et textes publics

Le message de référence est :

> iliprestō — Les services du quotidien assistés par IA. Particuliers et professionnels répondent rapidement aux besoins près de chez vous. Publiez une annonce préremplie automatiquement avec l’IA et échangez directement, avec 0 % de commission.

Les textes publics doivent respecter les règles suivantes :

- utiliser `ilipresto.fr` comme domaine de référence ;
- présenter iliprestō comme une plateforme nationale ;
- ne pas promettre un délai moyen de réponse tant que la métrique n’est pas démontrée sur une période et un volume suffisants ;
- ne pas présenter l’IA comme prenant la décision ou publiant sans validation humaine ;
- ne pas présenter iliprestō comme employeur, agence d’intérim, prestataire du service ou garant de la relation ;
- ne pas présenter iliprestō comme intermédiaire de paiement de la prestation ;
- distinguer clairement les abonnements à la plateforme du montant du service convenu entre utilisateurs.

## 8. Frontières et exclusions produit

Ne font pas partie du périmètre de référence :

- encaisser ou séquestrer le paiement des prestations entre utilisateurs ;
- prélever une commission sur le prix du service ;
- devenir partie au contrat de prestation entre les utilisateurs ;
- garantir la qualité, la réalisation ou le résultat d’une prestation ;
- employer les prestataires ou organiser une relation de subordination ;
- effectuer automatiquement une vérification exhaustive des antécédents ;
- publier une annonce produite par IA sans confirmation de l’utilisateur ;
- fournir un conseil juridique, fiscal ou social personnalisé et définitif ;
- afficher des coordonnées privées en dehors des règles d’autorisation prévues ;
- activer silencieusement le mode commercial ou les paiements.

## 9. Principes de sécurité et de qualité

- le client Flutter est considéré comme non fiable pour les décisions sensibles ;
- l’authentification, les rôles, les quotas, la publication, la modération et les droits commerciaux sont confirmés côté backend ;
- les erreurs exposées à l’utilisateur restent compréhensibles sans divulguer de données sensibles ;
- tout bug corrigé sur un parcours critique reçoit un test de non-régression ;
- les médias sont limités, validés et nettoyés ;
- les actions destructrices sont confirmées et auditées ;
- l’application doit rester utilisable sur les tailles d’écran supportées et avec les fonctions d’accessibilité prévues ;
- la release doit être observable et réversible.

## 10. Décisions fermées pour éviter les contradictions

| Sujet | Décision approuvée |
|---|---|
| Marché | National ; priorité d’acquisition initiale possible dans la Caraïbe sans régionaliser la marque |
| Commission | 0 % sur la prestation entre utilisateurs en bêta comme en mode commercial |
| Monétisation initiale | Abonnements de plateforme préparés ; aucune obligation de paiement en bêta gratuite |
| Paiement des services | Hors périmètre ; iliprestō n’encaisse pas la prestation |
| IA | Assistance à la rédaction, à la structuration et à la transcription ; validation finale humaine |
| Utilisateurs | Particuliers, indépendants et professionnels peuvent chercher ou proposer selon leurs droits |
| Domaine | `https://ilipresto.fr` est l’adresse publique de référence |
| Référencement | Aucun texte général ne limite iliprestō à l’outre-mer |
| Délai de réponse | Aucune promesse chiffrée publique sans preuve KPI documentée |
| Mode initial | `free_beta`, avec abonnements et Stripe désactivés côté utilisateur |
| Mode commercial | Activation explicite, auditée et conditionnée aux preuves juridiques, techniques et commerciales |
| Responsabilité | Outil de mise en relation et de communication, non employeur et non partie à la prestation |

## 11. Critères d’approbation du cadrage

Le cadrage produit est considéré approuvé lorsque :

- les rôles ci-dessus couvrent tous les parcours principaux ;
- chaque parcours prioritaire possède un propriétaire fonctionnel et des critères de validation ;
- les deux modes d’exploitation sont cohérents avec le code et les textes ;
- les exclusions empêchent de confondre mise en relation, paiement et exécution de la prestation ;
- les documents `business-model.md`, `kpi-framework.md` et `release-scope.md` restent alignés avec ce document ;
- toute contradiction détectée est corrigée avant la promotion du point 1.
