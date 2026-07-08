# Aperçu de la page « Mon parcours personnalisé » — Salarié × Agriculteur

Ce document reconstitue, section par section, ce que l'utilisateur voit réellement à l'écran
sur `_JourneySummaryPage` (`lib/pages/toolbox_je_me_lance_page.dart`) pour le couple
statut **Salarié** / activité **Agriculteur**, à partir de la fiche officielle
`salarie_agriculteur` (`assets/data/parcours_fiches_salarie.json`, index 102) et de la
logique actuelle de `_applyFicheToRecommendation` (post PR #140).

## Hypothèses retenues

Le contenu générique (hors fiche) dépend de quelques réponses du parcours qui ne sont pas
fixées par la fiche elle-même. Valeurs retenues pour cet aperçu — ce sont les valeurs par
défaut du wizard (étapes 1 à 4 ne redemandent pas ambition/CA visé/dépenses/business model) :

| Paramètre | Valeur |
|---|---|
| Région | Nouvelle-Aquitaine (hors DROM, pour ne pas ajouter les aides LODEOM/CTM au générique) |
| Statut actuel | Salarié |
| Activité | Agriculteur |
| Ambition | Tester l'idée (défaut) |
| Modèle | Ponctuel (défaut) |
| CA visé / Dépenses pro | 0 € (défaut) |
| Protection du patrimoine | Oui (défaut) |

Avec ces valeurs par défaut, le moteur générique recommande toujours **Micro-entrepreneur**
avant application de la fiche (aucun mot-clé réglementé dans le texte de projet, pas de
croissance visée, pas de marketplace).

---

## En-tête + Résumé de ma situation

> **Créer une activité de Agriculteur en Nouvelle-Aquitaine avec le statut actuel : Salarié**
> Parcours généré · 0 étape(s) terminée(s) sur 9

| Champ | Valeur affichée |
|---|---|
| Région | Nouvelle-Aquitaine |
| Statut actuel | Salarié |
| Activité | Agriculteur |
| **Niveau de vigilance** | **Très élevé** *(repris du `niveau_vigilance` de la fiche, plus le générique "Faible/Moyen" calculé côté app)* |
| Parcours recommandé | Création progressive *(texte générique, non alimenté par la fiche)* |

---

## 1. Comprendre les règles de votre activité

Tuiles générées par `regulationTutorial`, dans l'ordre d'affichage :

1. **Vue d'ensemble** — Ce parcours explique comment un profil « salarié » peut démarrer ou
   ajouter l'activité « Agriculteur ». Activité réglementée. Niveau de vigilance : très élevé.
2. **Activité : Agriculteur** — Activité agricole encadrée, relevant en principe de la MSA et
   du régime des bénéfices agricoles Famille : Agriculture / Production végétale ou animale.
   Code APE indicatif : 01.xx selon production : cultures, élevage, maraîchage, arboriculture,
   apiculture, horticulture — à confirmer. Nature fiscale probable : bénéfices agricoles BA :
   micro-BA ou régime réel agricole selon seuils et option.
3. **Règles à respecter** — Aucun diplôme général n'est obligatoire pour toute activité
   agricole, mais l'installation est fortement encadrée : affiliation MSA, foncier,
   autorisations d'exploiter selon situation, règles sanitaires, environnementales,
   bien-être animal, traçabilité, éventuellement Certiphyto pour produits phytosanitaires,
   identification animale, déclaration d'élevage, hygiène et agrément/dispense pour
   transformation ou vente alimentaire. La capacité professionnelle agricole peut être
   nécessaire ou déterminante pour certaines aides et installations.
4. **Assurances à prévoir** — RC exploitation agricole ; multirisque agricole ; assurance
   matériel et bâtiments ; assurance véhicule/tracteur ; protection juridique ; assurance
   récolte ou mortalité animale selon production.
5. **Organismes à consulter** — ACRE si éligible ; congé création/reprise ; temps partiel
   création/reprise ; BGE ; ADIE ; Initiative France ; Région ; Chambre consulaire
   compétente ; Chambre d'agriculture ; MSA ; Point accueil installation ; DAAF/DDT(M) ;
   FEADER ; SAFER ; Banque ; Assureur agricole.
6. **Organisme(s) de contrôle** — MSA, DAAF/DDT(M), Chambre d'agriculture, services
   vétérinaires/DDPP/DAAF, mairie, douanes/fiscalité selon production.
7. **Alertes spécifiques à l'activité** — Même sans clause écrite, l'obligation de loyauté
   interdit de nuire à l'employeur ou de détourner sa clientèle ; Une activité visible sur
   les réseaux sociaux peut exposer une concurrence ou un conflit d'intérêts ; Pour
   l'influence et le contenu digital, ne pas utiliser les marques, locaux, collègues,
   clients ou données de l'employeur sans autorisation ; Pour l'agriculture, vérifier
   fatigue, sécurité, engins, produits phytosanitaires et compatibilité horaires ; Ne pas
   orienter automatiquement vers micro-entrepreneur : agriculture relève de la MSA et des
   bénéfices agricoles ; Vérifier la taille de l'exploitation, le temps de travail et les
   revenus pour déterminer cotisant solidaire ou chef d'exploitation ; Vérifier foncier,
   bail rural, autorisation d'exploiter et règles locales avant tout investissement ;
   Vérifier sanitaire, traçabilité, élevage, bien-être animal, eau, déchets, pesticides et
   transformation alimentaire ; Le micro-BA est fiscal ; il ne remplace pas l'affiliation
   sociale MSA ; Point bloquant métier : confirmer MSA, micro-BA/réel agricole,
   surface/temps de travail et éventuel statut cotisant solidaire avant toute mise en ligne
   du parcours ; Vérifier que le volume agricole réel reste compatible avec le statut
   personnel, la santé, le temps disponible et les obligations principales.
8. **MSA — Le régime du micro-BA** — Régime micro-bénéfice agricole applicable aux
   exploitations agricoles sous seuil, y compris cotisants solidaires. —
   https://www.msa.fr/lfp/exploitant/micro-benefice-agricole
9. **MSA — La cotisation de solidarité** — Critères d'assujettissement du cotisant
   solidaire : surface, temps de travail et revenus. —
   https://www.msa.fr/lfp/cotisant-de-solidarite
10. **MSA — Les conditions d'installation** — Affiliation MSA selon le type d'activité et
    l'activité minimale d'assujettissement. — https://www.msa.fr/lfp/installation/conditions
11. **MSA — L'exonération jeune agriculteur** — Conditions d'exonération pour les jeunes
    agriculteurs, notamment âge et affiliation non-salarié agricole. —
    https://www.msa.fr/lfp/installation/exoneration-jeune-agriculteur
12. **Entreprendre Service Public — Seuils micro-entreprise 2026** — Seuils 2026 : 83 600 €
    pour prestations de services/professions libérales et 203 100 € pour ventes/commercial. —
    https://entreprendre.service-public.gouv.fr/vosdroits/F32353
13. **Entreprendre Service Public — Fiscalité d'un micro-entrepreneur** — Fiscalité micro,
    franchise en base de TVA et obligations déclaratives. —
    https://entreprendre.service-public.gouv.fr/vosdroits/F36244
14. **Entreprendre Service Public — ACRE** — ACRE 2026 : exonération temporaire, taux
    minoré égal à 75 % du taux normal pour les micro-entrepreneurs éligibles. —
    https://entreprendre.service-public.fr/vosdroits/F11677

*(14 tuiles au total : vue d'ensemble, activité, règles, assurances, organismes,
organisme de contrôle, alertes, + 7 sources officielles.)*

---

## 2. Vérifier votre situation personnelle

Une seule carte `_StatusGuidanceCard`, alimentée par `regles_statut` de la fiche :

> **Cumul d'activité — Agriculteur**
>
> L'utilisateur est salarié. Il peut créer une activité indépendante, mais il doit d'abord
> vérifier contrat de travail, convention collective, clause d'exclusivité, clause de
> non-concurrence, obligation de loyauté, confidentialité et temps de repos.

Checklist (`regles_statut.conditions`) :
- Relire contrat de travail et convention collective
- Identifier toute clause d'exclusivité, non-concurrence, confidentialité ou propriété
  intellectuelle
- Ne pas utiliser le matériel, les fichiers, les clients ou le temps de travail de
  l'employeur
- Éviter toute concurrence directe ou situation de conflit d'intérêts
- Adapter l'activité au temps disponible et aux règles de repos/santé au travail

---

## 3. Choisir le bon cadre pour démarrer

**Statut recommandé** *(`fiche['statut_recommande']`, reprend `parcours['3_cadre']` pour la
justification)* :

> micro-entreprise ou EI en complément d'activité si contrat compatible, activité hors
> temps salarié et absence de concurrence déloyale ; régime agricole spécifique si
> activité agricole

Bandeau d'aide : *"Des points de vigilance doivent être vérifiés avant de lancer les
démarches."* (car `blockingAlerts` contient 11 entrées, voir section 6).

**Important** *(`legal_review_status`)* :
> socle officiel 2026 intégré ; validation finale recommandée par organisme compétent,
> assureur, expert-comptable ou juriste avant mise en production

**Si votre activité se développe** *(`statut_alternatif`, 13 options jointes par « ou »)* :
> EI réel ou EURL ou SASU ou temps partiel création/reprise ou congé création/reprise ou
> société agricole si projet agricole structuré ou cotisant solidaire MSA ou chef
> d'exploitation agricole ou EI agricole au réel ou EARL ou GAEC ou SCEA ou SAS agricole
> selon projet

Chips de priorités (générique, non alimenté par la fiche) : `Simplicité` · `Protection`

---

## 4. Faire les démarches étape par étape

9 étapes (`_buildTutorialSteps`), todos remplacés par la fiche selon l'`id` de l'étape :

1. **Vérifier la réglementation de l'activité** — qualification_regles (texte ci-dessus) ;
   Code APE indicatif : 01.xx… ; + 6 assurances.
2. **Vérifier votre situation personnelle** — situationDescription (texte de la section 2).
   *(pas de "Contact utile" : la fiche n'a pas de champ `organisme_cumul`.)*
3. **Choisir le statut de lancement** — Statut conseillé : micro-entreprise ou EI en
   complément d'activité… ; Alternatives : EI réel, EURL, SASU, temps partiel
   création/reprise, congé création/reprise, société agricole si projet agricole
   structuré, cotisant solidaire MSA, chef d'exploitation agricole, EI agricole au réel,
   EARL, GAEC, SCEA, SAS agricole selon projet.
4. **Préparer les informations nécessaires** — 18 documents à collecter : contrat de
   travail, convention collective, avenants, planning ou horaires, accord employeur si
   nécessaire, attestation RC pro, description de l'activité complémentaire, description
   des productions, surface exploitée, bail rural ou titre d'occupation, volume horaire
   estimé, prévisionnel recettes/charges, contact MSA, contact Chambre d'agriculture,
   déclaration animaux si élevage, plan parcellaire, assurance agricole, certifications
   éventuelles.
5. **Déclarer l'activité** — 16 démarches (`parcours['4_demarches']`) + « Guichet : Guichet
   unique INPI pour l'immatriculation/modification + MSA + Chambre d'agriculture selon le
   projet ».
6. **Mettre en place les protections utiles** — les 6 assurances (même liste qu'à l'étape 1).
7. **Organiser la gestion** — 7 lignes fiscalité (`fiscalite`) : Regime Principal : BA :
   micro-BA ou réel agricole selon seuils et option ; Micro Ba : seuil MSA indiqué à
   120 000 € HT pour 2024 et 2025, à confirmer pour la période en vigueur et selon
   revalorisation ; Social : MSA : cotisant solidaire ou non-salarié agricole selon
   surface, temps de travail et revenus ; TVA : régime agricole spécifique possible ;
   vérifier remboursement forfaitaire agricole ou régime simplifié agricole selon
   situation ; CFE : possible selon commune et activité ; exonérations à vérifier ;
   Compte Bancaire : compte dédié conseillé ; obligatoire en micro si chiffre d'affaires
   > 10 000 € pendant 2 années consécutives ; Facturation : devis/factures/notes à
   conserver ; mentions obligatoires selon activité et TVA.
8. **Trouver les premières aides** — 15 aides (`parcours['5_aides']`) + « Organismes : ACRE
   si éligible, congé création/reprise, temps partiel création/reprise, BGE, ADIE,
   Initiative France, Région, Chambre consulaire compétente, Chambre d'agriculture, MSA,
   Point accueil installation, DAAF/DDT(M), FEADER, SAFER, Banque, Assureur agricole ».
9. **Lancer les premières offres** — 10 modes d'exercice (`modes_exercice`), chacun préfixé
   « Mode d'exercice possible : » — maraîchage, élevage, arboriculture, horticulture,
   apiculture, culture vivrière, transformation fermière, vente directe, marchés,
   prestation agricole accessoire.

---

## 5. Identifier les aides possibles

19 aides affichées (4 génériques pertinentes + 15 issues de la fiche, aucun doublon détecté
par le dédoublonnage nom-à-nom) :

**Génériques** (ARCE filtré, non pertinent hors "Demandeur d'emploi") :
- ACRE — Exonération partielle de cotisations au démarrage
- Prêt d'honneur — Initiative France / Réseau Entreprendre
- Aides territoriales — Région / Département / Agglo (selon territoire)
- Fonds européens — FEDER / FSE+ / FEADER (via programmes régionaux)

**Issues de la fiche** (`parcours['5_aides']`, description générique « Dispositif identifié
pour l'activité « Agriculteur » (fiche officielle). ») :
ACRE si éligible · congé création/reprise · temps partiel création/reprise · BGE · ADIE ·
Initiative France · Région · Chambre consulaire compétente · Point accueil installation ·
exonération jeune agriculteur MSA si conditions · DJA / aides installation selon
territoire · FEADER · Chambre agriculture · prêt d'honneur agricole · Aides-territoires

> ⚠️ À noter : plusieurs entrées ci-dessus sont des quasi-doublons textuels des génériques
> (« ACRE » vs « ACRE si éligible », « Prêt d'honneur » vs « prêt d'honneur agricole »,
> « Aides territoriales » vs « Aides-territoires »). Le dédoublonnage compare les noms en
> minuscules **à l'identique** : ces variantes ne sont pas reconnues comme doublons et
> s'affichent donc toutes les deux.

---

## 6. Prévoir les coûts de lancement

> **Alertes à vérifier** — 11 point(s) de vigilance détecté(s) avant lancement.

| Poste | Montant | Origine |
|---|---|---|
| Frais de formalités | ≈ 0 à 50 € | générique (Micro-entrepreneur) |
| Annonce légale | ≈ 0 € | générique |
| Assurance professionnelle | ≈ 250 € | générique |
| Comptable / an | ≈ 0 € | générique |
| Banque + outils / an | ≈ 120 € | générique |

**Note de lecture** *(remplacée par la fiche : `costs['note']` = `couts_indicatifs.join(' ')`)* :
> formalités : variables selon immatriculation et accompagnement foncier / bail / fermage :
> coût majeur matériel agricole : de quelques centaines à plusieurs dizaines de milliers
> d'euros semences, plants, alimentation animale : variable eau, irrigation, clôtures,
> serres : variable assurance agricole : variable cotisations MSA : à simuler
> comptabilité agricole : conseillée transport et marchés : variable

> ⚠️ À noter : cette note remplace entièrement le texte générique ("Estimations
> indicatives…") par la concaténation brute des 9 items de `couts_indicatifs`, sans
> ponctuation entre eux — le texte s'affiche comme un bloc continu peu lisible.

**Coûts détaillés propres à votre activité** (mêmes 9 items, mais en liste à puces
lisible) :
- formalités : variables selon immatriculation et accompagnement
- foncier / bail / fermage : coût majeur
- matériel agricole : de quelques centaines à plusieurs dizaines de milliers d'euros
- semences, plants, alimentation animale : variable
- eau, irrigation, clôtures, serres : variable
- assurance agricole : variable
- cotisations MSA : à simuler
- comptabilité agricole : conseillée
- transport et marchés : variable

---

## 7. Votre plan d'action sur 30 jours

14 tâches (10 génériques + 1 tâche fiche insérée en tête de chaque semaine) :

**Semaine 1**
1. *(fiche)* Décrire la production, identifier surface, parcelles, matériel, contacter
   Chambre d'agriculture, contacter MSA, vérifier foncier et bail
2. Vérifier activité réglementée (si concerné)
3. Choisir statut + option TVA
4. Lister 10 clients cibles + offre + tarif

**Semaine 2**
1. *(fiche)* Vérifier autorisation d'exploiter, vérifier règles sanitaires/environnementales,
   vérifier élevage ou transformation, choisir régime social MSA, préparer prévisionnel
2. Contacter CCI/CMA/BGE de Nouvelle-Aquitaine et prendre 1 RDV
3. Chercher aides sur Aides-territoires pour la région Nouvelle-Aquitaine

**Semaine 3**
1. *(fiche)* Déclarer via Guichet unique si nécessaire, finaliser affiliation MSA, choisir
   fiscalité BA, souscrire assurance, mettre en place suivi recettes/charges
2. Monter dossier ACRE / France Travail (si concerné)
3. Préparer dossier subvention (résumé + budget + devis)

**Semaine 4**
1. *(fiche)* Acheter priorités, tester vente directe ou marchés, mettre en place
   traçabilité, vérifier prix de revient, archiver documents
2. Déposer formalités via guichet unique
3. Assurances + compte bancaire pro si nécessaire
4. 1ère action commerciale (prospection / pub / partenariats)

---

## Sauvegarde & partage

> Abonnement Gratuit : sauvegarde en local sur cet appareil. Avec IliPresto+ ou ilipro :
> sauvegarde en local + export PDF sur votre téléphone + partage.

`[Sauvegarder]`

---

## Champs de la fiche non repris dans le parcours

Pour être exhaustif vis-à-vis de la fiche source, les champs suivants existent dans
`salarie_agriculteur.json` mais ne sont **pas** affichés sur cette page (ils servent
ailleurs — recherche/indexation ou n'ont pas d'équivalent UI) :

- `id`, `id_fiche`, `statut_key`, `categorie` : utilisés pour l'indexation/le matching,
  pas affichés tels quels.
- `titre` (« Agriculteur indépendant — salarié ») : n'apparaît nulle part sur la page (le
  titre affiché reste « Agriculteur », `selectedActivity`).
- `search_keys`, `version` : métadonnées internes.
- `parcours['0_identite']` et `parcours['1_regles']` : leur contenu est dupliqué ailleurs
  (vue d'ensemble / qualification_regles) mais ces clés précises ne sont jamais lues
  individuellement par `_applyFicheToRecommendation`.
