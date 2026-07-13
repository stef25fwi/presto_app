# Définitions des KPI produit et business

## Règles générales

- utiliser le même fuseau et la même définition d’une période ;
- distinguer demandeurs, prestataires et professionnels ;
- séparer les territoires ;
- calculer les cohortes depuis la date d’inscription ;
- exclure les comptes internes, tests et fraude ;
- documenter toute modification de définition.

## Acquisition

### Conversion visite → inscription

```text
inscriptions valides / visiteurs uniques consentants
```

### CAC

```text
dépenses acquisition attribuables / nouveaux utilisateurs activés
```

Le CAC par inscription est secondaire ; le CAC par utilisateur activé est plus utile.

## Activation

### Profil complété

Utilisateur ayant renseigné les champs nécessaires à son rôle, sans utiliser de données de test.

### Première valeur

Premier événement parmi :

- annonce publiée et visible ;
- contact qualifié initié ;
- réponse qualifiée reçue ;
- parcours entrepreneur généré et consulté.

### Time to Value

```text
heure de première valeur - heure d’inscription
```

Suivre médiane, p75 et p90.

## Liquidité marketplace

### Annonce avec réponse

Annonce ayant reçu au moins une prise de contact non bloquée et non signalée sous la fenêtre observée.

### Taux de couverture 48 h

```text
annonces avec contact qualifié sous 48 h / annonces publiées
```

### Délai avant première réponse

Mesurer la médiane et le p90 par catégorie, commune et jour de la semaine.

### Densité d’offre

```text
prestataires actifs disponibles / annonces actives
```

Interpréter par catégorie et territoire, jamais seulement au global.

## Engagement

### DAU, WAU, MAU

Utilisateur unique ayant réalisé une action de valeur, et non simplement ouvert l’application.

### Stickiness

```text
DAU / MAU
```

### Mise en relation qualifiée

Annonce avec interaction pertinente entre deux comptes distincts, sans signalement confirmé ni automatisation interne.

## Rétention

### Rétention J7

Part des inscrits d’une cohorte ayant réalisé une action de valeur entre J7 et J8 après inscription.

### Rétention J30

Même principe entre J30 et J31. Conserver une définition constante pour comparer les cohortes.

### Réactivation

Utilisateur inactif depuis au moins 30 jours revenant effectuer une action de valeur.

## Conversion et revenu

### Conversion gratuit → payant

```text
nouveaux abonnés confirmés / utilisateurs gratuits éligibles exposés à l’offre
```

### MRR

Somme normalisée mensuellement des abonnements actifs confirmés par Stripe, hors TVA selon la convention comptable retenue, remboursements et paiements irrécouvrables.

### ARPU

```text
revenu récurrent de la période / utilisateurs actifs de la période
```

### ARPPU

```text
revenu récurrent de la période / utilisateurs payants actifs
```

### Churn logo mensuel

```text
abonnés perdus pendant le mois / abonnés actifs au début du mois
```

### Churn revenu

```text
MRR perdu - expansion MRR / MRR au début du mois
```

### LTV simplifiée

```text
ARPPU mensuel × marge brute / churn mensuel
```

Cette formule n’est utilisable que lorsque le churn est suffisamment stable.

## Qualité et sécurité

- taux de signalement par 1 000 annonces ;
- fraude confirmée ;
- blocages et recours ;
- temps de traitement support ;
- taux de remboursement ;
- litiges par mise en relation ;
- disponibilité et sessions sans crash.

## Coût unitaire

### Coût cloud par MAU

```text
coûts Firebase + IA + email + stockage / MAU
```

### Coût par mise en relation qualifiée

```text
coûts variables de plateforme / mises en relation qualifiées
```

## Gouvernance

Chaque KPI doit avoir un propriétaire, une source, une fréquence, une requête de référence, un seuil d’alerte et une décision associée. Un chiffre sans décision associée ne doit pas encombrer le tableau de bord principal.
