# Phase 13 — Accessibilité, UX et design system

## Objectif

Rendre les parcours principaux utilisables sur smartphone, tablette et desktop, avec une conformité WCAG AA mesurable et un design system cohérent.

## Contrôles suivis

- design system centralisé : espacements, typographie, couleurs, états et composants ;
- contrastes WCAG AA ;
- navigation clavier et focus visibles ;
- sémantique lecteur d’écran ;
- tailles tactiles suffisantes ;
- mise en page responsive avec texte agrandi ;
- états loading, empty et error cohérents ;
- audit des parcours inscription, publication, consultation, contact, abonnement et compte.

## Sources de vérité

- registre : `quality/accessibility_ux_readiness.json` ;
- design system : `docs/design/design-system.md` ;
- baseline d’audit : `docs/evidence/ux/accessibility-audit.md` ;
- matrice responsive : `docs/evidence/ux/responsive-matrix.md` ;
- tokens : `lib/app/presto_design_tokens.dart` ;
- thème : `lib/app/theme.dart`.

## Validation

Le registre `quality/accessibility_ux_readiness.json` constitue la source de vérité. Le workflow génère un rapport JSON conservé trente jours. Un contrôle ne passe à `verified` qu’avec une preuve réelle : test widget, audit, capture, rapport automatisé ou validation sur appareil.

Les anciens registres utilisant `complete` restent lisibles pour compatibilité, mais toute nouvelle validation utilise `verified`, conformément au superviseur séquentiel 18/18.

## État de la fondation au 2 août 2026

- design system centralisé : preuves produites, validation CI requise ;
- couples de contraste officiels : tests automatisés ajoutés ;
- cibles standards : minimum 48 × 48 px imposé dans le thème ;
- clavier : test de fondation ajouté, parcours complets encore ouverts ;
- responsive : breakpoints et test 320 px / 200 % ajoutés, matrice complète encore ouverte ;
- lecteur d’écran, états asynchrones et audit final : en cours.

## Definition of Done

- audit WCAG AA sans anomalie critique ;
- parcours principaux utilisables au clavier et avec lecteur d’écran ;
- aucun débordement aux tailles de texte élevées ;
- états d’interface cohérents ;
- composants du design system documentés et réutilisés ;
- huit contrôles au statut `verified` ;
- `flutter analyze --fatal-infos` et la suite Flutter complète au vert ;
- promotion du point 2 vers le point 3 produite par l’agent séquentiel.
