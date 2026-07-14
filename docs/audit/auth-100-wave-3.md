# Auth 100 % — vague 3

Cette vague couvre les composants d’interface Auth sans dépendance Firebase :

- `AuthErrorBox` ;
- `AuthPrimaryButton` ;
- `AuthTextField` ;
- `ResetPasswordSuccessPage`.

Critères :

- aucun seuil abaissé ;
- aucun fichier Auth exclu ;
- comportements vide, succès, chargement, options du champ et navigation retour couverts ;
- validation finale assurée par la CI et `tools/quality/report_auth_coverage.py`.
