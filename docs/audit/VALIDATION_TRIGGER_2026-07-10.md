# Validation complète du durcissement

Ce commit déclenche les contrôles GitHub Actions sur l’état généré de la branche `audit/prod-hardening-p0-p11`.

Contrôles attendus :

- garde-fous de production ;
- analyse CodeQL ;
- analyse et tests Flutter ;
- build et tests des Cloud Functions ;
- tests Firestore Rules avec Emulator ;
- build Web release ;
- budget du bundle Web.

Aucune modification fonctionnelle n’est introduite par ce fichier.
