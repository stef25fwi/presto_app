# Modèle économique iliprestō

## Statut du document

- Version : 1.0
- Date d’approbation : 2026-08-02
- Statut : approuvé pour le programme de préparation au lancement
- Mode initial : bêta gratuite
- Principe permanent : 0 % de commission sur le montant des prestations entre utilisateurs

## 1. Principe général

iliprestō monétise l’accès à des capacités de plateforme et non la prestation réalisée entre les utilisateurs.

Le montant, les conditions, l’exécution et le règlement d’un service sont convenus directement entre les utilisateurs. iliprestō n’encaisse pas ce règlement, ne le séquestre pas et ne prélève aucune commission sur celui-ci.

Le modèle économique est organisé en deux étapes :

1. une bêta gratuite destinée à valider l’usage, la liquidité locale, la qualité des parcours et les coûts ;
2. un mode commercial activé ultérieurement, reposant principalement sur des abonnements optionnels à la plateforme.

## 2. Bêta gratuite

### Objectifs

- vérifier que les utilisateurs comprennent la proposition de valeur ;
- mesurer la capacité à publier une annonce et à obtenir une mise en relation ;
- valider les parcours IA, messagerie, modération et création d’activité ;
- mesurer les coûts Firebase, stockage, notifications et IA ;
- corriger les défauts avant toute monétisation ;
- constituer les premiers indicateurs d’usage sans créer de friction de paiement.

### Configuration produit obligatoire

| Paramètre | Valeur bêta |
|---|---|
| Mode d’exploitation | `free_beta` |
| Section abonnements | Désactivée |
| Stripe côté utilisateur | Désactivé |
| Accès libre | Activé pour les fonctions ouvertes par la bêta |
| Commission sur prestation | 0 % |
| Documents légaux | Versions bêta gratuite |
| Changement de mode | Réservé à une action administrative explicite et auditée |

### Règles de communication

Pendant la bêta :

- aucun utilisateur ne doit croire qu’un abonnement est nécessaire ;
- aucune fonction ne doit afficher un prix comme condition d’accès si le mode libre l’ouvre ;
- les limites techniques, anti-abus et de coûts peuvent continuer à s’appliquer ;
- les offres futures peuvent être préparées dans le code et l’administration sans être promues comme actives ;
- la mention « 0 % de commission » concerne le montant du service convenu entre utilisateurs.

## 3. Mode commercial préparé

Le mode commercial repose sur trois niveaux : Gratuit, iliprestō+ et ilipro.

Les tarifs mensuels actuellement préparés dans le backend sont :

| Offre | Tarif mensuel préparé | Public principal |
|---|---:|---|
| Gratuit | 0 € | Utilisateur occasionnel |
| iliprestō+ | 1,99 € | Utilisateur régulier souhaitant davantage de visibilité et de capacités |
| ilipro | 9,99 € | Indépendant ou professionnel utilisant iliprestō comme outil d’activité |

Ces tarifs restent une décision commerciale configurable avant lancement. Toute modification doit être synchronisée entre Stripe, le backend, les écrans, les documents légaux et les tests E2E.

## 4. Droits préparés par offre

### Marketplace et IA

| Capacité | Gratuit | iliprestō+ | ilipro |
|---|---:|---:|---:|
| Annonces actives | 3 | 10 | 30 |
| Photos par annonce | 1 | 5 | 10 |
| Brouillons IA texte par mois | 2 | Illimité fonctionnel | Illimité fonctionnel |
| Utilisations IA vocale par mois | 1 | 5 | Illimité fonctionnel |
| Favoris | Oui | Oui | Oui |
| Alertes de favoris | Non | Oui | Oui |
| Mise en avant d’annonce | Selon mode libre | Oui | Oui |
| Appel direct | Selon mode libre | Oui | Oui |
| Statistiques | Non | Non | Oui |
| Profil professionnel | Non | Non | Oui |
| Badge vérifié | Non | Oui selon règles | Oui selon règles |
| Badge professionnel | Non | Non | Oui selon vérification |

### Messagerie

En mode bêta libre, les documents, photos et audios peuvent être ouverts largement sous réserve des limites de sécurité et de stockage.

En mode commercial préparé :

| Capacité | Gratuit | iliprestō+ | ilipro |
|---|---:|---:|---:|
| Documents en conversation | Non | Oui | Oui |
| Photos par conversation | 1 | Limite technique élevée | Limite technique élevée |
| Audios par conversation | 1 | Limite technique élevée | Limite technique élevée |

Les valeurs élevées ne suppriment pas les limites de taille, de type MIME, de fréquence, de stockage, de modération ou d’abus.

### Parcours « Je me lance »

| Capacité mensuelle | Gratuit | iliprestō+ | ilipro |
|---|---:|---:|---:|
| Sauvegardes locales | 2 | 5 | 10 |
| Export PDF | Non | Oui | Oui |
| Exports PDF | 0 | 5 | 10 |
| Logo et filigrane | Sans objet | Obligatoires | Obligatoires |

## 5. Sources de revenus

### Source principale approuvée

Les abonnements optionnels à la plateforme constituent la source principale préparée.

Ils rémunèrent notamment :

- l’augmentation des quotas ;
- les fonctions IA plus intensives ;
- les capacités avancées de messagerie ;
- les alertes et outils de visibilité ;
- les fonctions professionnelles ;
- les statistiques ;
- les exports et outils de création d’activité.

### Revenus secondaires possibles

La publicité peut constituer une source secondaire lorsque :

- elle respecte le consentement et les obligations des stores ;
- elle ne dégrade pas les parcours critiques ;
- elle ne présente pas un annonceur comme recommandé par iliprestō ;
- les identifiants de test et de production sont correctement séparés ;
- les revenus et l’impact sur la rétention sont mesurés.

Aucune autre source de revenus n’est considérée active sans décision produit, juridique et technique dédiée.

## 6. Ce qui n’est pas monétisé

- aucune commission sur le prix du service ;
- aucun frais obligatoire pour répondre à une annonce pendant la bêta ;
- aucune vente de données personnelles ;
- aucun paiement pour obtenir une décision de modération favorable ;
- aucune vente de faux avis, de classement artificiel ou de badge non vérifié ;
- aucun encaissement du règlement entre demandeur et prestataire.

## 7. Conditions d’activation du mode commercial

Le mode commercial reste interdit tant que l’ensemble des conditions suivantes n’est pas rempli :

1. identité juridique commerciale complète ;
2. mentions légales, CGU et politique de confidentialité commerciales approuvées ;
3. catalogue Stripe conforme aux montants affichés ;
4. webhook signé, idempotence, cycle de vie, réconciliation et alertes validés ;
5. test E2E avec un compte Firebase réel ;
6. politique Android/iOS décidée pour les fonctions numériques payantes ;
7. documents de facturation et support prêts ;
8. matrice des droits vérifiée côté backend ;
9. mesure des coûts et seuils d’alerte actifs ;
10. décision go/no-go enregistrée.

L’activation doit :

- être réalisée par une personne autorisée ;
- modifier de manière cohérente la configuration légale et la configuration abonnements ;
- produire une entrée d’historique ;
- déclencher la version commerciale des documents ;
- demander une nouvelle acceptation lorsque nécessaire ;
- être réversible vers `free_beta` sans modifier le code.

## 8. Politique de paiement selon la plateforme

### Web

Stripe peut être utilisé pour les abonnements lorsque le mode commercial est actif et que les contrôles de production sont validés.

### Android et iOS

Avant toute commercialisation mobile, il faut décider et appliquer une politique conforme aux règles des stores :

- achat intégré lorsque les fonctionnalités numériques l’exigent ;
- ou parcours d’abonnement limité au Web lorsque cette organisation est conforme et clairement séparée ;
- aucune ouverture silencieuse d’un checkout Stripe depuis une application mobile si cela contrevient aux règles applicables.

Le point 16 du programme 18/18 doit fournir la preuve de cette décision et de son implémentation.

## 9. Économie unitaire et suivi des coûts

Les coûts doivent être suivis au minimum par domaine :

- Firebase Hosting ;
- Firestore lectures, écritures, stockage et trafic ;
- Cloud Functions, Cloud Run et Scheduler ;
- Storage et traitement des médias ;
- IA texte, transcription, vision et audio ;
- notifications et fournisseur email ;
- observabilité et services tiers ;
- frais Stripe ;
- support, modération et exploitation.

Les mesures obligatoires sont :

- coût mensuel total ;
- coût par utilisateur actif mensuel ;
- coût par annonce publiée ;
- coût par mise en relation qualifiée ;
- coût IA par traitement et par annonce aboutie ;
- marge brute par abonnement ;
- revenu moyen par compte payant ;
- délai de récupération du coût d’acquisition.

Des alertes doivent être configurées à 50 %, 80 % et 100 % du budget mensuel approuvé. Le budget peut évoluer, mais il doit toujours être versionné et associé à un propriétaire.

## 10. Hypothèses de validation commerciale

La bêta doit permettre de tester les hypothèses suivantes :

1. une proportion suffisante de visiteurs comprend l’offre et crée un compte ;
2. les utilisateurs arrivent à publier une annonce sans assistance humaine ;
3. les annonces reçoivent des réponses utiles dans les zones lancées ;
4. les utilisateurs reviennent publier, répondre ou poursuivre une conversation ;
5. l’IA augmente le taux d’achèvement sans générer un coût disproportionné ;
6. une part des utilisateurs réguliers valorise les capacités iliprestō+ ;
7. les professionnels valorisent les statistiques, le profil et les capacités ilipro ;
8. les abonnements peuvent financer les coûts sans introduire de commission.

Aucune hypothèse n’est considérée validée par le seul nombre d’inscriptions. Les critères sont définis dans `kpi-framework.md`.

## 11. Règles anti-contradiction

| Risque de contradiction | Règle définitive |
|---|---|
| « Gratuit » alors que Stripe est visible | Stripe et la section abonnements restent masqués en `free_beta` |
| « 0 % de commission » interprété comme produit entièrement gratuit pour toujours | La commission sur la prestation reste nulle ; des abonnements de plateforme optionnels peuvent exister |
| Abonnement confondu avec paiement du service | Les deux flux sont séparés dans les textes, le code et le support |
| Offre payante activée sans société prête | Le service refuse le passage commercial si les informations juridiques requises manquent |
| Retour checkout utilisé comme preuve | Seul le webhook ou une vérification backend met à jour les droits |
| Prix différents entre application et Stripe | Le backend contrôle le montant, la devise et l’intervalle du catalogue |
| Quotas contournés côté client | Les droits et quotas sensibles sont contrôlés ou confirmés côté serveur |
| Paiement mobile non conforme | Le mode commercial mobile reste bloqué jusqu’à la décision du point 16 |

## 12. Décision approuvée

Le modèle économique de référence est donc :

> une bêta gratuite pour valider l’usage, suivie d’abonnements optionnels à bas prix pour financer les capacités avancées, tout en maintenant 0 % de commission sur les prestations et un échange direct entre les utilisateurs.
