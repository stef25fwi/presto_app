# Calculatrice de l'entrepreneur — Standard et Expert

Le mode Rapide est fusionné dans Standard. La calculatrice propose désormais
deux parcours dont les champs, résultats et actions sont réellement distincts.

| Fonction | Standard | Expert |
| --- | --- | --- |
| Coûts matières, emballage et consommables | Oui | Oui |
| Temps de travail et taux horaire | Oui | Oui |
| Charges fixes et volume cible | Oui | Oui |
| Amortissement du matériel | Oui | Oui |
| Frais externes, marge et TVA | Oui | Oui |
| Prix minimum, prix conseillé et alerte de perte | Oui | Oui |
| Électricité, eau, transport et autres coûts | Non | Oui |
| Tarifs régionaux Firestore | Non | Oui |
| Positionnement marché | Non | Oui |
| Scénarios prudent, cible et haut | Non | Oui |
| Seuil de rentabilité mensuel détaillé | Synthèse | Oui |
| Sauvegarde et historique local | Non | Oui |
| Export PDF | Non | Oui |

## Règles communes

- iliprestō n'ajoute aucune commission au calcul.
- Les frais saisis correspondent aux frais externes réellement supportés.
- Le prix envisagé est comparé au prix minimum rentable.
- La part d'amortissement est intégrée au coût de revient unitaire.
- Les montants de TVA et les tarifs régionaux restent modifiables.

## Données régionales Expert

Le mode Expert lit les documents Firestore suivants avec le code du territoire :

- `tarifs_electricite/{code_region}` ;
- `tarifs_eau/{code_region}`.

Les champs reconnus sont `prixKwh`, `pricePerKwh`, `tarifKwh` ou `value` pour
l'électricité et `prixM3`, `pricePerM3`, `tarifM3` ou `value` pour l'eau.
