# Correctifs iliprestō réunis — 30 septembre 2026

Base : `main@e56851b6087ad28d9a100f8191955df0a6a8bb40`.
Branche locale : `fix/ilipresto-audit-integration-20260930`.

## Produit et sécurité

Les PR #1458 à #1463 sont intégrées ensemble sans conflit : écritures de
messagerie uniquement par callable, retrait du déverrouillage anonyme de
pré-lancement, conservation du formulaire entre onglets, brouillon durable
isolé par compte et expirant après sept jours, publication manuelle avec IA
facultative, pagination filtrée et panneau conservé pendant l'auto-application.
Les photos temporaires ne sont pas restaurées après redémarrage.
Le hero Home et ses trois affiches restent préservés.

La transcription Google du chemin V1 conserve désormais le meilleur résultat
de chaque segment, au lieu de ne conserver que le premier. Le test couvre une
dictée dont la ville et le budget sont reconnus dans des segments ultérieurs,
ainsi qu'un premier segment vide. Cela corrige un défaut source prouvé ; cela
ne démontre pas la résolution du smoke vocal en production ou des évaluations
IA live sous les seuils.

## Dépendances et livraison

L'audit actuel a trouvé brace-expansion en sévérité haute dans les deux
périmètres, nodemailer en sévérité haute dans Functions et qs en sévérité
modérée à la racine. Les deux lockfiles sont corrigés, notamment nodemailer
10.0.13, brace-expansion >= 2.1.7 et qs >= 6.16.0.

Le workflow de production exige désormais le verdict strict de préparation
sécurité avant l'authentification GCP et audite la racine et les Functions.
Le workflow d'audit couvre et archive les deux périmètres. La vérification
post-déploiement exige que version.json sur ilipresto.fr et ilipresto.web.app
annonce exactement le SHA du workflow, avec reprises limitées.

## Vérifications locales

- Audits npm de production racine et Functions : zéro vulnérabilité.
- Compilation TypeScript et tests Functions : 356 réussis, 2 ignorés,
  zéro échec (Node 24 local ; CI prévue en Node 22).
- Tests de sécurité et bootstrap pré-lancement : 37 réussis.
- Trois suites Firestore en émulateur (annonces publiques, règles canoniques
  et autorité des utilisateurs) : réussies, aucun accès production.
- Contrôle strict : refus attendu, trois preuves obligatoires en attente.
- Scripts de maintenance, 15 garde-fous de production, tailles et couplage
  Flutter, syntaxe JavaScript/YAML et git diff --check : réussis.

## Limites et suite requise

La branche n'est ni publiée, ni fusionnée, ni déployée. La revue automatique
a refusé son push faute d'autorisation explicite de publication sur GitHub.
La CI Flutter complète et le build web doivent être exécutés sur le SHA
réunissant les correctifs ; Flutter est indisponible localement.

Les restrictions des clés API, l'inventaire des secrets et la revue OWASP
restent en attente ; aucun statut n'est promu artificiellement. La protection
de main nécessite encore une configuration GitHub d'administration. Aucun
secret, réglage Remote Config ou compte de production n'a été modifié.

Les parcours réels connectés et paiements ainsi que la certification sur
appareils Android/iOS et les publications stores restent à valider. La PR
#1407 décrit les secrets de signature Android nécessaires ; #1408 traite la
suppression de compte, avec contrôles externes encore requis. Ces lots mobile
ne sont pas inclus dans cette intégration.
