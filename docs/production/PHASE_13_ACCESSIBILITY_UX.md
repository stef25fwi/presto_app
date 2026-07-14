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

## Validation

Le registre `quality/accessibility_ux_readiness.json` constitue la source de vérité. Le workflow génère un rapport JSON conservé trente jours. Un contrôle ne passe à `complete` qu’avec une preuve réelle : test widget, audit, capture, rapport automatisé ou validation sur appareil.

## Definition of Done

- audit WCAG AA sans anomalie critique ;
- parcours principaux utilisables au clavier et avec lecteur d’écran ;
- aucun débordement aux tailles de texte élevées ;
- états d’interface cohérents ;
- composants du design system documentés et réutilisés.
