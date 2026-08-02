# Cadre KPI iliprestō

## Statut du document

- Version : 1.0
- Date d’approbation : 2026-08-02
- Statut : approuvé pour la bêta gratuite et la préparation commerciale
- Propriétaire : produit, avec validation technique pour les définitions d’événements

## 1. Objectif

Ce cadre définit comment iliprestō mesure l’acquisition, l’activation, la liquidité de la marketplace, la rétention, la confiance, la qualité IA, les revenus et les coûts.

Une fonctionnalité n’est pas considérée réussie uniquement parce qu’elle est disponible dans le code. Elle doit produire un résultat observable, mesurable et compatible avec les objectifs de sécurité, de qualité et de coût.

## 2. Principes de mesure

1. chaque KPI possède une définition stable, une source, une fréquence et un propriétaire ;
2. les métriques ne doivent pas stocker de contenu de message, transcription ou donnée personnelle inutile ;
3. les données doivent distinguer environnement, plateforme, région, version et mode d’exploitation ;
4. les utilisateurs de test, administrateurs et automatisations doivent être exclus des KPI commerciaux ;
5. les taux utilisent un dénominateur explicite et une fenêtre temporelle fixe ;
6. une moyenne n’est jamais utilisée seule lorsqu’une médiane ou un percentile révèle mieux les écarts ;
7. les promesses publiques chiffrées exigent une preuve documentée sur un volume suffisant ;
8. les résultats de bêta ne sont pas extrapolés automatiquement au marché national.

## 3. Indicateur principal

### Mise en relation qualifiée

Une mise en relation est qualifiée lorsque :

- elle est liée à une annonce valide ;
- deux comptes distincts participent à la conversation ;
- chaque partie a envoyé au moins un message non système ;
- l’échange réciproque intervient dans les sept jours suivant le premier contact ;
- aucun des comptes n’est identifié comme compte de test ou administrateur d’exploitation.

Cet indicateur mesure une interaction réelle sans prétendre que la prestation a été conclue ou réalisée.

### North Star Metric

> Nombre hebdomadaire de mises en relation qualifiées.

Cet indicateur doit toujours être accompagné de :

- la part des annonces publiées ayant obtenu une mise en relation qualifiée ;
- le délai jusqu’à la première réponse ;
- le nombre de signalements ou blocages liés à ces relations ;
- le coût moyen par mise en relation qualifiée.

## 4. Entonnoir d’acquisition

| KPI | Définition | Source principale | Fréquence |
|---|---|---|---|
| Visiteurs uniques | Navigateurs ou appareils uniques consentis ayant chargé une page publique | Analytics Web/App | Quotidienne |
| Sessions d’acquisition | Sessions provenant d’un canal identifiable | Analytics et paramètres de campagne | Quotidienne |
| Taux visite → inscription commencée | Inscriptions commencées / visiteurs éligibles | Analytics produit | Hebdomadaire |
| Taux inscription commencée → compte créé | Comptes créés / inscriptions commencées | Firebase Auth + événements produit | Hebdomadaire |
| Taux compte créé → email vérifié | Comptes vérifiés / comptes email créés | Firebase Auth | Hebdomadaire |
| Coût d’acquisition | Dépenses d’acquisition / nouveaux comptes éligibles | Comptabilité + Analytics | Mensuelle |
| Acquisition organique | Nouveaux comptes sans campagne payante identifiée | Analytics | Mensuelle |

### Objectifs de bêta

- mesurer 100 % des créations de compte par plateforme et version ;
- identifier le canal d’acquisition lorsqu’un consentement et un paramétrage valides le permettent ;
- ne fixer aucun CAC cible définitif avant le premier cycle de campagne mesurable ;
- maintenir une distinction entre trafic national, zones de lancement prioritaire et trafic interne.

## 5. Activation

### Activation demandeur

Un demandeur est activé lorsqu’il réalise au moins une des actions suivantes dans les sept jours suivant la création du compte :

- publier une annonce approuvée ;
- engager une conversation qualifiable depuis une annonce existante.

### Activation prestataire

Un prestataire est activé lorsqu’il :

- complète les informations minimales de profil ;
- puis envoie une première réponse autorisée à une annonce dans les sept jours.

### Activation créateur d’activité

Un utilisateur de « Je me lance » est activé lorsqu’il :

- renseigne région, statut et activité ;
- génère son parcours ;
- puis ouvre ou valide au moins une étape.

| KPI | Calcul |
|---|---|
| Taux d’activation demandeur J7 | Demandeurs activés sous 7 jours / nouveaux comptes ayant exprimé un besoin |
| Taux d’activation prestataire J7 | Prestataires activés sous 7 jours / nouveaux comptes ayant commencé un profil ou une réponse |
| Taux de publication aboutie | Annonces approuvées / créations d’annonce commencées |
| Taux d’abandon de publication | Créations commencées sans soumission dans les 24 heures / créations commencées |
| Taux de génération de parcours | Parcours générés / formulaires « Je me lance » commencés |
| Taux de première étape | Parcours avec une étape ouverte ou cochée / parcours générés |

### Seuils initiaux de sortie de bêta

Ces seuils sont des objectifs de validation, pas des promesses publiques :

- publication aboutie : au moins 70 % des parcours commencés hors erreurs techniques ;
- génération du parcours « Je me lance » : au moins 75 % des formulaires commencés ;
- erreurs techniques bloquantes d’activation : moins de 2 % des tentatives ;
- événements d’activation correctement instrumentés : au moins 98 % des parcours éligibles.

## 6. Liquidité de la marketplace

| KPI | Définition |
|---|---|
| Annonces publiées | Annonces approuvées sur la période |
| Offre active | Comptes ayant répondu à une annonce ou déclaré une compétence active sur la période |
| Taux d’annonces avec réponse | Annonces ayant reçu au moins une réponse humaine autorisée / annonces publiées |
| Taux d’annonces avec mise en relation qualifiée | Annonces ayant produit au moins une relation qualifiée / annonces publiées |
| Délai première réponse | Temps entre publication et première réponse humaine autorisée |
| Réponses par annonce | Nombre médian de répondants distincts par annonce |
| Couverture géographique | Zones ayant un minimum d’annonces et de répondants actifs |
| Taux de recherche sans résultat | Recherches valides sans résultat / recherches valides |

### Segmentation obligatoire

- catégorie de service ;
- commune ou zone agrégée suffisamment large ;
- plateforme ;
- nouveaux et anciens utilisateurs ;
- annonce avec ou sans assistance IA ;
- période de lancement.

### Règle sur la promesse « réponse en moins de 10 minutes »

Cette promesse ne peut être affichée publiquement que si :

1. au moins 500 annonces éligibles ont été mesurées ;
2. la mesure couvre au moins 30 jours consécutifs ;
3. les comptes de test, réponses automatiques et administrateurs sont exclus ;
4. la médiane et la moyenne sont toutes deux inférieures à 10 minutes ;
5. au moins 70 % des annonces reçoivent une réponse dans la fenêtre annoncée ;
6. le résultat reste vrai sur les principales catégories et zones affichées ;
7. une preuve datée est conservée dans `docs/evidence/product/`.

À défaut, les textes utilisent une formulation non chiffrée telle que « échangez rapidement ».

## 7. Engagement et rétention

| KPI | Définition |
|---|---|
| Utilisateur actif quotidien | Compte ayant réalisé une action de valeur dans la journée |
| Utilisateur actif hebdomadaire | Compte ayant réalisé une action de valeur sur sept jours |
| Utilisateur actif mensuel | Compte ayant réalisé une action de valeur sur trente jours |
| WAU/MAU | Utilisateurs actifs hebdomadaires / utilisateurs actifs mensuels |
| Rétention J7 | Nouveaux comptes actifs entre J7 et J13 / cohorte de création |
| Rétention J30 | Nouveaux comptes actifs entre J30 et J44 / cohorte de création |
| Réactivation | Comptes inactifs depuis 30 jours redevenus actifs |
| Fréquence d’usage | Jours actifs médians par utilisateur actif mensuel |

Une action de valeur est : publier, répondre, échanger dans une conversation, gérer une annonce, consulter une ressource de parcours ou effectuer une action de suivi. Une simple ouverture de l’application ne suffit pas.

### Seuils exploratoires

- suivre séparément demandeurs, prestataires et créateurs d’activité ;
- viser une rétention J30 d’au moins 15 % sur les demandeurs occasionnels ;
- viser une rétention J30 d’au moins 25 % sur les prestataires actifs ;
- ne pas agréger les cohortes tant que les volumes d’un segment sont insuffisants.

Ces seuils doivent être révisés après les trois premières cohortes mensuelles complètes.

## 8. Messagerie et notifications

| KPI | Définition |
|---|---|
| Taux d’ouverture de conversation | Conversations ouvertes / contacts autorisés initiés |
| Taux de réciprocité | Conversations avec messages des deux parties / conversations humaines commencées |
| Délai de réponse conversation | Temps entre message initial et première réponse de l’autre partie |
| Messages échoués | Envois en erreur / tentatives d’envoi |
| Pièces jointes échouées | Uploads ou traitements en erreur / tentatives |
| Push délivrés | Notifications acceptées par le fournisseur / notifications tentées |
| Push ouverts | Ouvertures attribuées / push délivrés lorsque mesurable |
| Blocages | Conversations bloquées / conversations actives |
| Suppressions | Messages ou conversations supprimés / objets éligibles |

Les métriques ne doivent pas inclure le contenu des messages ou des fichiers.

## 9. Confiance, sécurité et modération

| KPI | Définition | Seuil initial |
|---|---|---:|
| Taux de signalement d’annonce | Annonces signalées / annonces consultées | À surveiller par catégorie |
| Taux de signalement de conversation | Conversations signalées / conversations actives | À surveiller |
| Délai de première prise en charge | Temps entre signalement et première action de modération | Médiane < 24 h |
| Délai de résolution | Temps entre signalement et décision finale | 90 % < 48 h en exploitation normale |
| Taux de décisions renversées | Décisions modifiées après recours / décisions finales | < 5 % après stabilisation |
| Faux positifs automatiques | Contenus légitimes bloqués à tort / contenus contrôlés | Mesure obligatoire avant durcissement |
| Comptes à privilèges revus | Comptes admin/modération revus / comptes à privilèges | 100 % par trimestre |

Toute période de crise ou d’indisponibilité doit être annotée pour ne pas masquer une dégradation réelle.

## 10. Qualité IA

| KPI | Définition |
|---|---|
| Taux de succès IA | Traitements terminés avec un résultat conforme / traitements commencés |
| Taux de sortie invalide | Réponses ne respectant pas le schéma / réponses reçues |
| Taux de fallback | Traitements V2 repliés vers V1 ou autre moteur / traitements V2 |
| Taux de cache | Réponses servies depuis le cache / traitements éligibles |
| Latence IA p50/p95 | Durée médiane et 95e percentile par opération |
| Acceptation du brouillon | Brouillons conservés avec modifications limitées / brouillons proposés |
| Abandon après IA | Parcours abandonnés après résultat IA / résultats IA affichés |
| Coût par traitement | Coût modèle et transcription / traitements |
| Coût par annonce publiée avec IA | Coût IA total / annonces IA finalement publiées |

### Seuils initiaux

- taux de succès technique : au moins 95 % hors médias invalides et coupures utilisateur ;
- sortie structurée invalide : moins de 2 % ;
- taux de fallback V2 : inférieur à 25 % ;
- aucune promotion de modèle sans jeu d’évaluation reproductible ;
- aucune conservation durable des transcriptions ou audios au-delà de la politique approuvée.

Les seuils de rollback définis dans le runbook IA restent prioritaires lorsqu’ils sont plus stricts.

## 11. Qualité technique

| KPI | Cible de référence |
|---|---:|
| Sessions sans crash | ≥ 99,5 % |
| Affichage initial cible | ≤ 2,5 s dans les conditions de référence |
| Interaction locale courante | ≤ 200 ms |
| Erreurs HTTP/Callable non métier | < 1 % |
| Disponibilité des parcours critiques | ≥ 99,5 % mensuel après lancement commercial |
| Couverture LCOV globale | ≥ 70 % |
| Couverture modules critiques | ≥ 85 % |
| Couverture paiement et droits | ≥ 90 % |
| Régressions critiques non détectées avant production | 0 tolérée |

Les conditions de référence, appareils, navigateurs et réseaux utilisés doivent être documentés dans les preuves du point correspondant.

## 12. Revenus et conversion commerciale

Ces KPI ne deviennent actifs qu’en mode commercial.

| KPI | Définition |
|---|---|
| MRR | Revenu récurrent mensuel normalisé des abonnements actifs |
| Nouveaux MRR | MRR provenant des nouvelles souscriptions |
| Expansion MRR | Augmentations de plan sur la période |
| Contraction MRR | Réductions de plan hors résiliation |
| Churn MRR | MRR perdu par résiliation ou impayé / MRR initial |
| Conversion payante | Comptes devenus payants / comptes éligibles exposés à l’offre |
| ARPPU | Revenu mensuel / comptes payants actifs |
| Durée de vie payante | Durée moyenne ou médiane d’un abonnement |
| Échec de paiement | Factures impayées / factures émises |
| Recouvrement | Abonnements récupérés après impayé / abonnements en impayé |

### Seuils avant extension commerciale

- webhooks traités sans perte connue ;
- réconciliation Stripe quotidienne opérationnelle ;
- écarts catalogue/application : zéro ;
- droits activés uniquement par preuve backend ;
- taux d’échec technique du checkout inférieur à 1 % hors refus bancaire ;
- marge brute positive par offre sur une cohorte représentative.

Aucun objectif de MRR n’est déclaré atteint sans revenu effectivement encaissé et rapproché.

## 13. Coûts et efficacité

| KPI | Calcul |
|---|---|
| Coût d’infrastructure | Dépenses cloud et services techniques de la période |
| Coût par MAU | Coût d’infrastructure / utilisateurs actifs mensuels |
| Coût par annonce | Coûts attribuables / annonces publiées |
| Coût par relation qualifiée | Coûts attribuables / mises en relation qualifiées |
| Coût IA par utilisateur actif | Coût IA / utilisateurs ayant utilisé l’IA |
| Marge brute abonnement | Revenu net - coûts variables attribuables |
| Budget consommé | Dépenses cumulées / budget mensuel approuvé |

Les alertes budgétaires sont déclenchées à 50 %, 80 % et 100 % du budget mensuel approuvé. Une hausse anormale doit être reliée à une version, une fonction, un fournisseur ou un changement de trafic.

## 14. Tableau de bord minimum de bêta

Le tableau de bord hebdomadaire doit afficher :

1. visiteurs, créations de compte et vérifications ;
2. activation demandeur, prestataire et « Je me lance » ;
3. annonces publiées et taux de publication aboutie ;
4. annonces avec réponse et relations qualifiées ;
5. délai de première réponse p50 et p95 ;
6. DAU, WAU, MAU et rétention par cohorte ;
7. conversations réciproques ;
8. signalements, délais de modération et blocages ;
9. succès, latence, fallback et coût IA ;
10. sessions sans crash et erreurs critiques ;
11. coût cloud total, coût par MAU et budget consommé.

Le tableau commercial ajoute MRR, conversion, churn, ARPPU, impayés et marge brute.

## 15. Gouvernance des données KPI

- chaque événement possède un nom, une version et une description ;
- les changements incompatibles créent une nouvelle version ;
- les événements de test portent un environnement non production ;
- les durées de conservation sont documentées ;
- les exports n’incluent pas de texte libre utilisateur sauf nécessité légale validée ;
- l’accès aux tableaux de bord suit le principe du moindre privilège ;
- un contrôle mensuel compare les métriques applicatives et les sources backend ;
- toute métrique utilisée dans une communication publique reçoit une preuve datée.

## 16. Critères de validation du cadre KPI

Le cadre est considéré approuvé lorsque :

- la mise en relation qualifiée est l’indicateur principal partagé ;
- l’acquisition, l’activation, la liquidité, la rétention, la confiance, l’IA, les revenus et les coûts ont une définition ;
- les promesses chiffrées disposent d’une règle de preuve ;
- les comptes de test et administrateurs sont exclus des résultats commerciaux ;
- les seuils initiaux peuvent être révisés sans modifier les définitions historiques ;
- les mesures respectent la minimisation des données et les règles RGPD.
