# Audit couverture et prévision de délai — 14 juillet 2026

Basé sur la baseline LCOV réelle versionnée dans #321
(`docs/quality/lcov-real-baseline-after-320.md`) et sur la vélocité mesurée
entre les baselines du 11 juillet (#178) et du 14 juillet (#321).

## 1. État des lieux vérifié

| Indicateur | 11 juillet (#178) | 14 juillet (#321) | Delta |
|---|---:|---:|---:|
| Couverture globale | 10,95 % | 14,97 % | +4,02 pts |
| Lignes couvertes (est.) | ≈ 4 355 | 5 953 | ≈ +1 600 |
| Fichiers de test | 51 | 77 | +26 |
| Lignes de test | 6 388 | 8 555 | +2 167 |
| Couverture Auth | 2,93 % | 48,07 % | +45,14 pts |

Vélocité observée sur ce sprint (cadence agents, ~20 PR de couverture
mergées en 3 jours) :

- **≈ 530 lignes couvertes / jour** ;
- **≈ 80 lignes couvertes / PR** ;
- rendement ≈ 0,75 ligne couverte par ligne de test écrite.

## 2. Points de vigilance sur le dénominateur

1. **Le LCOV ne voit que les fichiers importés par les tests.** Le workflow
   exécute `flutter test --coverage` sans helper d'import global : 257
   fichiers instrumentés pour 315 fichiers Dart dans `lib/`. Environ 58
   fichiers n'existent pas encore dans le LCOV ; quand des tests les
   toucheront, le dénominateur (39 772 lignes) grossira, ce qui ralentit
   mécaniquement la progression du pourcentage. Provision : **+10 à +20 %**
   de lignes cibles supplémentaires.
2. **La vélocité actuelle porte sur les fruits mûrs** : policies extraites,
   mappers, validateurs, widgets, services isolés. Le stock restant est
   dominé par les fichiers P0 géants (`toolbox_je_me_lance_page.dart`
   7 178 lignes, `admin_space_page.dart` 5 695, `publish_offer_page.dart`
   5 342, etc.), couplés à Firestore/Stripe/plugins, qui exigent une
   décomposition préalable (chantier « Phase 1 architecture » en cours).

## 3. Modèle de vélocité retenu

| Phase | Contenu | Vélocité estimée |
|---|---|---:|
| A — fruits mûrs restants | policies, services extraits, petites pages | 450–550 lignes/j |
| B — pages moyennes, repositories, admin avec fakes | | 250–350 lignes/j |
| C — fichiers P0 géants après décomposition, branches d'erreur, code plateforme | | 100–200 lignes/j |

## 4. Prévision de délai (cadence sprint maintenue, 7 j/7)

Base : 5 953 / 39 772 lignes. Les dates intègrent la phase A puis la
décroissance de vélocité ; la fourchette haute intègre la croissance du
dénominateur (+15 %).

| Palier global | Lignes à ajouter | Délai central | Échéance estimée |
|---:|---:|---:|---|
| 20 % | +2 001 | ~4 j | ~18 juillet 2026 |
| **25 % (palier officiel)** | +3 990 | ~8 j | **~22–25 juillet 2026** |
| 40 % | +9 956 | ~28 j | ~mi-août 2026 |
| 50 % | +13 933 | ~40 j | ~fin août – début sept. 2026 |
| 70 % | +21 887 | ~95 j | ~mi-octobre – début nov. 2026 |
| 85 % | +27 853 | ~135 j | ~fin nov. – déc. 2026 |
| 100 % | +33 819 | ~210 j+ | **~février–mars 2027, non réaliste sans exclusions** |

Auth 100 % (539 lignes restantes, dont 480 dans trois fichiers à refactorer
pour être testables sans Firebase) : **4 à 6 jours** au rythme Auth observé.

Si la cadence retombe à un rythme humain classique (~100–150 lignes
couvertes/jour), multiplier les délais par ~3,5 : 50 % se joue alors au
premier trimestre 2027.

## 5. Recommandations

1. **Ne pas viser 100 % global.** Les dernières ~15 % de lignes (bootstrap,
   code plateforme, branches d'erreur inatteignables, pages générées)
   coûtent plus que les 85 premières. Cible saine : **85 % sur les modules
   critiques** (déjà la cible de `quality/critical-coverage.json`) et
   **60–70 % global**.
2. **Décider des exclusions LCOV explicites** (`// coverage:ignore-file`
   ou filtrage `lcov --remove`) pour le code non testable, et les
   documenter — sans jamais les utiliser pour gonfler un module.
3. **Refactor d'abord sur les P0** : la phase C est bornée par la
   décomposition des fichiers géants, pas par l'écriture de tests. Le
   guardrail de taille (#317) est le bon levier ; chaque décomposition doit
   livrer ses tests de caractérisation.
4. **Cliqueter les planchers** (`minimum_percent`) après chaque palier
   atteint pour rendre la progression irréversible.
5. **Ajouter un helper d'import global de couverture** (ou un job dédié)
   pour que le dénominateur reflète tout `lib/` dès maintenant, plutôt que
   de découvrir la dette en cours de route.

## 6. Effort total estimé

Couvrir les 33 819 lignes restantes au rendement observé (~0,75 ligne
couverte par ligne de test) représente **≈ 45 000 lignes de test**, soit
environ **5× la suite actuelle** (8 555 lignes). C'est l'ordre de grandeur
qui justifie de plafonner la cible globale à 60–70 %.
