# Audit de conservation des informations — fiche Aide déménagement

Date de validation : 16 juillet 2026.

## Conclusion

Le parcours réel, depuis la fiche JSON et son contenu Markdown jusqu’au PDF, conserve désormais les informations détaillées sans réduction silencieuse.

## Pertes détectées puis corrigées

1. Les sources officielles pouvaient disparaître lorsque le contenu Markdown détaillé était utilisé.
2. Les étapes Markdown recevaient des identifiants génériques, empêchant le rattachement fiable des règles, coûts, aides et avertissements à l’étape correspondante.
3. Les coûts détaillés et les valeurs fiscales pouvaient être remplacés par une note synthétique.
4. L’étape finale de lancement n’était pas intégrée à l’ordre canonique du PDF.
5. La fiche complète provoquait une erreur de pagination lorsque toutes les informations étaient conservées.
6. La déduplication des sources supprimait toutes les URL après la première, car l’empreinte normalisée effaçait le contenu des URL.

## Corrections permanentes

- dix identifiants d’étapes canoniques ;
- conservation des coûts et valeurs fiscales détaillés ;
- ajout de toutes les sources officielles ;
- déduplication exacte des URL ;
- découpage des cartes selon le nombre d’actions et le volume de texte ;
- découpage des actions très longues ;
- limite de pagination portée à 100 pages ;
- espace minimal avant une nouvelle carte pour éviter les titres isolés ;
- test Flutter fondé sur la fiche JSON et Markdown réelles ;
- extraction textuelle du PDF et contrôle automatique des données sensibles ;
- rendu PNG pour contrôle visuel.

## Résultat vérifié

- 10 étapes chronologiques conservées ;
- 8 sources officielles attendues et 8 présentes ;
- PDF A4 de 16 pages ;
- seuil micro-fiscal 2026 : 83 600 euros ;
- cotisations micro-sociales BIC services : 21,2 % ;
- seuils de franchise TVA : 37 500 et 41 250 euros ;
- cumul fonction publique, documents, assurances, biens confiés, manutention et transport pour compte d’autrui conservés ;
- autorisation d’exercer, capacités professionnelle et financière, inscription au registre et licence conditionnelle clairement distinguées ;
- aucun bloc Nova SAP, public fragile, acte médical ou matériel de ménage réintroduit ;
- aucun titre d’étape isolé après le dernier contrôle visuel.

## Décision

La fiche reste `corrigee` et n’est pas déclarée `validee` tant que le volet transport pour compte d’autrui n’a pas reçu sa validation spécialisée.

Les preuves machine-readable se trouvent dans `quality/parcours_information_preservation_validation.json`. Le contrôle permanent est exécuté par `.github/workflows/parcours-information-preservation.yml`.
