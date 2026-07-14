# Phase 16 — exécution prioritaire des 9 contrôles go-live

Date de préparation : 2026-07-14

## Règle de décision

Le déploiement continu peut se poursuivre. L'ouverture publique avec paiements réels reste bloquée tant que les contrôles ci-dessous ne disposent pas d'une preuve réelle et datée.

## 1. Tag release candidate

Préparer un tag au format `vYYYY.MM.DD-rc.N` sur un commit `main` entièrement vert.

Preuve exigée :
- nom du tag ;
- SHA exact ;
- lien vers le workflow de validation ;
- artefact `production-release-<sha>` disponible.

Statut actuel : pending. Aucun tag RC n'est créé par ce document.

## 2. Smoke tests production

Commande officielle :

```bash
bash tools/production/run_smoke_tests.sh
```

Vérifications minimales :
- page d'accueil HTTP 200 ;
- manifest HTTP 200 ;
- chargement d'un asset Flutter ;
- absence de réponse HTML sur les fichiers JavaScript ;
- disponibilité d'un endpoint Functions non destructif ;
- capture UTC, commit et cible Firebase.

Tentative du 2026-07-14T22:14:57Z depuis l'environnement assistant : non concluante, résolution DNS indisponible (`Could not resolve host`). Cette tentative ne constitue pas une preuve de succès.

Statut actuel : pending jusqu'à exécution dans GitHub Actions ou un poste disposant d'un accès réseau valide.

## 3. Rollback testé

Procédure :
1. sélectionner l'artefact `production-release-<sha précédent>` ;
2. restaurer d'abord sur un canal Firebase Hosting isolé ;
3. exécuter les smoke tests sur ce canal ;
4. documenter la durée et le résultat ;
5. ne restaurer la production qu'en cas d'incident réel ou exercice explicitement approuvé.

Preuve exigée : run GitHub Actions, SHA restauré, URL du canal isolé, résultats des smoke tests, temps total.

Statut actuel : pending. La procédure existe, mais aucun exercice daté n'est encore enregistré.

## 4. Contacts incident confirmés

Rôles obligatoires :
- Incident Commander ;
- responsable technique Firebase/Flutter ;
- responsable paiements Stripe ;
- responsable support utilisateurs ;
- remplaçant.

Pour chaque rôle : nom, canal principal, canal secondaire, disponibilité et date de confirmation.

Statut actuel : pending tant que les coordonnées nominatives ne sont pas renseignées dans un document privé ou un secret organisationnel approprié. Ne jamais versionner de numéro personnel sensible dans un dépôt public.

## 5. Playbook support

Le playbook est défini dans `docs/production/SUPPORT_PLAYBOOK.md`.

Il couvre : triage P0 à P3, accusé de réception, collecte des preuves, escalade technique, incidents paiement, communication utilisateur et clôture.

Statut actuel : verified après fusion de cette branche.

## 6. Dashboards monitoring

Dashboards requis :
- Firebase Crashlytics / erreurs Flutter ;
- Cloud Functions erreurs, latence et taux 5xx ;
- Firestore lectures/écritures et refus de règles ;
- Firebase Hosting disponibilité ;
- Stripe paiements, webhooks échoués, abonnements impayés ;
- support : tickets ouverts, âge et sévérité.

Preuve exigée : captures datées ou liens d'accès, seuils d'alerte et destinataires vérifiés.

Statut actuel : pending. La liste est définie, mais le caractère `live` doit être confirmé dans les consoles.

## 7. Assets légaux et stores

Checklist :
- mentions légales ;
- politique de confidentialité ;
- CGU ;
- politique de suppression de compte ;
- coordonnées éditeur/DPO ou contact confidentialité ;
- captures stores ;
- icônes et splash ;
- descriptions FR/EN/ES si publiées ;
- classification d'âge ;
- déclarations données collectées Apple/Google ;
- URLs support et confidentialité accessibles.

Statut actuel : pending jusqu'à validation humaine et, pour les stores, validation des fiches Apple/Google.

## 8. Décision go/no-go

Décision enregistrée le 2026-07-14 : **NO-GO pour ouverture publique avec transactions réelles**.

Motifs :
- Auth mesurée à 48,07 % sur la baseline après #320 ;
- paiements/abonnements sous le premier palier public recommandé ;
- contrôles opérationnels de phase 16 non terminés.

Autorisations maintenues :
- déploiement continu après CI verte ;
- staging, preview et bêta fermée ;
- tests production non destructifs.

Critères de réexamen : Auth à 100 % LCOV réel, chemins financiers critiques couverts, smoke tests et rollback prouvés, contacts/monitoring/légal confirmés.

Statut actuel : verified après fusion de cette branche.

## 9. Revue post-lancement

La revue doit être programmée pour J+7 après l'ouverture publique et inclure :
- incidents et temps de résolution ;
- erreurs Auth et paiement ;
- taux de conversion ;
- tickets support ;
- coûts Firebase/Stripe ;
- décisions de correction et responsables.

Statut actuel : pending, car la date d'ouverture publique n'est pas encore fixée. La réunion sera créée dès qu'une date go-live est décidée.
