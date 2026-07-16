# Programme de révision de toutes les fiches parcours iliprestō

## Finalité

Le programme transforme chaque fiche en guide chronologique fiable. Il corrige simultanément le référentiel métier, les règles de combinaison des données et le rendu PDF. Une amélioration de mise en page seule n'est pas suffisante.

## Les 15 contrôles du programme

1. **Geler les blocs non structurés** — toute modification du catalogue déclenche l'audit CI.
2. **Inventorier le catalogue** — le rapport recense fichiers, familles, statuts, risques et publication possible.
3. **Séparer les sources de données** — universel, situation utilisateur, activité, territoire et valeurs réglementaires datées.
4. **Auditer automatiquement** — doublons, champs absents, mélange métier, anglais visible, source invalide, valeur non datée et chronologie incohérente.
5. **Valider un pilote de 20 activités** — chaque activité est testée avec six profils minimum.
6. **Utiliser le nouveau générateur** — situation, blocages, calendrier, guide pas à pas, courriers, sources et checklist finale.
7. **Réviser les familles à risque élevé** — bâtiment, santé, garde, publics fragiles, transport, sécurité, alimentation et professions réglementées.
8. **Réviser les autres familles par lots** — une famille cohérente à la fois, jamais dans un ordre aléatoire.
9. **Centraliser les modèles** — courriers de cumul, France Travail, assurance, autorisation, financement, devis, facture et contrats.
10. **Tester automatiquement** — le script et ses tests deviennent un contrôle permanent de régression.
11. **Contrôler visuellement les PDF** — mobile, multipage, tableaux, sauts de page, liens, cases et lisibilité.
12. **Publier seulement une fiche validée** — `review_status=validee`, sans blocage ni erreur.
13. **Archiver les versions remplacées** — conservation de la version précédente et de la preuve de validation.
14. **Planifier la révision** — `reviewed_at` et `next_review_at` obligatoires dans la cible.
15. **Appliquer la définition de terminé** — checklist humaine signée et audit automatique réussi.

## Flux de révision par fiche

1. Importer la fiche dans l'inventaire.
2. Exécuter l'audit automatique.
3. Corriger la classification et supprimer les blocs étrangers.
4. Vérifier la réglementation et les sources.
5. Réécrire les démarches dans l'ordre chronologique.
6. Ajouter seulement les courriers conditionnels utiles.
7. Compléter les métadonnées de révision.
8. Tester les profils applicables.
9. Générer le PDF et effectuer le contrôle visuel.
10. Passer la fiche à `validee`, puis à `publiee` après déploiement.

## Priorisation

- **P0** : risque juridique, sécurité physique, transport, santé, bâtiment, garde, alimentation.
- **P1** : risque administratif ou financier, aides, agrément, investissement important.
- **P2** : activité libre simple, tout en conservant les contrôles anti-mélange.

## Commandes

```bash
node --test tools/quality/check_parcours_fiches.test.mjs
node tools/quality/check_parcours_fiches.mjs
node tools/quality/check_parcours_fiches.mjs --enforce
```

Le mode normal produit un état des lieux complet sans empêcher la migration du catalogue historique. Le mode `--enforce` est destiné aux lots corrigés et à la future bascule globale.
