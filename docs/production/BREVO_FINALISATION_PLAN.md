# iliprestō — Plan de finalisation Brevo à 100 %

> **Objectif** : disposer d’une configuration Brevo entièrement certifiée pour iliprestō, couvrant l’envoi transactionnel, la réception de `contact@ilipresto.fr`, la délivrabilité, les webhooks, la sécurité des secrets, l’observabilité, les tests E2E et l’administration ChatGPT/MCP.
>
> **État de référence** : 25 août 2026.
>
> **Principe** : une case ne doit être cochée que lorsqu’une preuve technique ou une vérification dans Brevo/Firebase/DNS existe. Ne pas déduire qu’un réglage est actif uniquement parce que le code correspondant existe dans le dépôt.

---

## 1. Définition du « 100 % Brevo production »

La configuration Brevo d’iliprestō peut être déclarée **100 %** uniquement lorsque les conditions suivantes sont toutes remplies :

- [ ] Le domaine `ilipresto.fr` est vérifié et authentifié dans Brevo.
- [ ] Les enregistrements DNS nécessaires à l’envoi sont tous valides.
- [ ] SPF est valide.
- [ ] DKIM est valide.
- [ ] DMARC est présent et valide.
- [ ] L’expéditeur `noreply@ilipresto.fr` existe et est actif.
- [ ] Le `Reply-To` de production est `contact@ilipresto.fr`.
- [ ] `BREVO_API_KEY` de production est valide et stockée uniquement dans Secret Manager.
- [ ] `BREVO_WEBHOOK_SECRET` de production est valide et stocké uniquement dans Secret Manager.
- [ ] Le webhook transactionnel Brevo est unique, sécurisé par Bearer et abonné à tous les événements requis.
- [ ] Un email transactionnel réel est accepté par Brevo, livré et confirmé par webhook dans Firestore.
- [ ] Le domaine entrant `inbound.ilipresto.fr` est correctement délégué/configuré pour Brevo.
- [ ] `contact@ilipresto.fr` est effectivement routé vers le pipeline entrant Brevo d’iliprestō.
- [ ] Le webhook entrant est sécurisé et reçoit réellement les emails.
- [ ] Les emails entrants apparaissent dans `adminInboundEmails` et sont accessibles uniquement aux administrateurs.
- [ ] Les bounces, plaintes et suppressions sont suivis.
- [ ] Les templates transactionnels nécessaires sont validés et cohérents avec l’identité iliprestō.
- [ ] La certification GitHub `quality/brevo-production` passe au vert sur le SHA réellement déployé.
- [ ] Les preuves de certification E2E sont archivées.
- [ ] Un runbook incident Brevo est opérationnel.
- [ ] Le connecteur ChatGPT ↔ Brevo MCP est activé lorsque le plan ChatGPT le permet.

---

# 1 bis. État constaté le 25 août 2026

Relevé effectué depuis l'API Brevo (lecture seule) et depuis deux résolveurs DNS publics indépendants (`1.1.1.1` et `8.8.8.8`). Ce relevé est un instantané : il doit être refait par `quality/brevo-production` avant toute déclaration de conformité.

## Ce qui est en place

- Compte Brevo de production actif : organisation `ilipresto`, plan **Starter payant**, 5 000 crédits d'envoi sur la période du 22 août au 22 septembre 2026.
- Relais SMTP transactionnel activé (`smtp-relay.brevo.com:587`).
- `GET /v3/account` répond correctement via le connecteur MCP Brevo de claude.ai (authentification OAuth propre au connecteur, **distincte** de la clé API de production — voir le blocage #0 ci-dessous, où cette dernière échoue).
- `_dmarc.ilipresto.fr` existe et publie `v=DMARC1; p=quarantine;`.

## Blocages P0 confirmés

| # | Constat vérifié | Conséquence | Section |
|---|---|---|---|
| 0 | **La clé `BREVO_API_KEY` de Secret Manager est rejetée par Brevo (HTTP 401)**, tout comme l'ancienne `EMAIL_PROVIDER_API_KEY`. Le canari envoyé par le runtime Firebase déployé n'obtient aucun accusé de réception avant expiration (90 s). Preuve : run `quality/brevo-production` [#54](https://github.com/stef25fwi/presto_app/actions/runs/32893628913), 25 août 2026 20:11 UTC. | **L'envoi transactionnel réel est cassé en production dès aujourd'hui** — pas seulement « pas encore certifié ». Aucune réparation automatique (`--repair`) n'a jamais pu s'exécuter : elle échoue avant le premier appel d'écriture. Ce blocage est antérieur à tous les autres : rien d'autre ne peut être vérifié tant qu'il n'est pas levé. | 6 |
| 1 | **Aucun enregistrement SPF** sur `ilipresto.fr` (seuls `google-site-verification` et `hosting-site` sont publiés) | Aucun envoi ne peut aligner SPF | 4.2 |
| 2 | **Aucun enregistrement DKIM** publié (ni `mail._domainkey`, ni `brevo._domainkey`, ni `brevo-code`) | Le domaine ne peut pas être authentifié chez Brevo | 4.3 |
| 3 | **DMARC `p=quarantine` sans SPF ni DKIM alignés**, et sans `rua` | Tout email partant aujourd'hui est mis en quarantaine ou en spam, et aucun rapport n'est reçu pour le constater | 4.4 |
| 4 | **Aucun expéditeur sur `ilipresto.fr`** : le seul sender du compte est `sahai.stephane@gmail.com` | `noreply@ilipresto.fr` n'existe pas ; un sender personnel de test est actif en production | 5 |
| 5 | **MX inbound cassé** : `inbound.ilipresto.fr` pointe vers `inbound1.sendinblue.com.ilipresto.fr` (point final absent chez LWS) et le second MX manque | `contact@ilipresto.fr` ne peut pas être reçu | 9.1 |

> **Ordre de traitement imposé par le blocage #0.** Publier une nouvelle clé API Brevo dans Secret Manager (`BREVO_API_KEY`) avant toute autre action. Sans clé valide, `check_brevo_sender_dns.mjs` ne peut même pas récupérer les valeurs DKIM attendues (`source: unavailable` dans le run #54), et `brevo_deliverability_report.mjs`/`brevo_suppression_hygiene.mjs` échouent immédiatement. Générer la clé dans Brevo (`Paramètres du compte` → `Clés API` → `Générer une nouvelle clé API v3`), la stocker avec `gcloud secrets versions add BREVO_API_KEY --project=presto-app-74abe --data-file=-`, puis rejouer `quality/brevo-production`.
>
> **Première rotation insuffisante (25 août 2026, ~23h40 UTC).** Une nouvelle clé a été générée dans Brevo et stockée comme version 8 du secret `BREVO_API_KEY` (les versions 1 à 7, créées entre le 22 mars et le 16 avril 2026, correspondent aux 4 clés désormais désactivées visibles dans Brevo). Le run `quality/brevo-production` [#56](https://github.com/stef25fwi/presto_app/actions/runs/32911573634) a rejoué la certification avec cette version 8 comme `latest` : **Brevo la rejette encore en HTTP 401**, et le canari via le runtime Firebase déployé échoue toujours par timeout. Deux causes restent à départager avant une nouvelle tentative :
> - la clé nouvellement créée n'est peut-être pas restée active côté Brevo (à vérifier sur `app.brevo.com` → SMTP et API) ;
> - la valeur collée dans la version 8 est peut-être corrompue (espace/retour à la ligne parasite) — à confirmer avec un test `curl` direct depuis un poste non lié à ce dépôt, jamais en collant la clé dans une conversation.

Constat annexe : le compte ne contient qu'un template Brevo, `Nouveau template`, inactif, sujet `test`, avec le contenu de démonstration Brevo (`Your order is coming soon`, `contact@company.com`). Les templates transactionnels iliprestō sont rendus côté code (`functions/src/modules/email/templates/definitions/`) : ce template de démonstration doit être supprimé pour lever toute ambiguïté.

## Correctifs DNS à publier chez LWS

Les valeurs DKIM exactes sont fournies par Brevo lors de l'ajout du domaine (`Expéditeurs et domaines` → `Domaines` → `Authentifier`) : les publier telles quelles, sans les reconstruire à la main.

```text
# SPF — un seul enregistrement TXT v=spf1 sur le domaine racine
ilipresto.fr.            TXT    "v=spf1 include:spf.brevo.com -all"

# DKIM — valeurs exactes affichées par Brevo (ne pas inventer les sélecteurs)
<sélecteur>._domainkey.ilipresto.fr.   TXT    "<valeur fournie par Brevo>"
brevo-code.ilipresto.fr.               TXT    "<code de vérification Brevo>"

# DMARC — conserver p=quarantine seulement une fois SPF et DKIM alignés,
# et ajouter une boîte de rapports réellement surveillée
_dmarc.ilipresto.fr.     TXT    "v=DMARC1; p=none; rua=mailto:dmarc@ilipresto.fr; pct=100"

# Inbound — noter le point final, absent aujourd'hui côté LWS
inbound.ilipresto.fr.    MX 10  inbound1.sendinblue.com.
inbound.ilipresto.fr.    MX 20  inbound2.sendinblue.com.
```

- [ ] Publier le SPF Brevo.
- [ ] Publier les enregistrements DKIM fournis par Brevo.
- [ ] Ajouter `rua` sur le DMARC et repasser temporairement en `p=none` le temps d'aligner SPF et DKIM.
- [ ] Corriger les deux MX de `inbound.ilipresto.fr` avec le point final.
- [ ] Créer `noreply@ilipresto.fr` dans Brevo et désactiver le sender `sahai.stephane@gmail.com`.
- [ ] Supprimer le template de démonstration `Nouveau template`.
- [ ] Rejouer `quality/brevo-production` et vérifier que `BREVO_SENDER_DNS_RESULT` remonte `ok:true`.

> Une fois SPF et DKIM alignés et vérifiés sur au moins une semaine de trafic réel, durcir DMARC : `p=none` → `p=quarantine` → `p=reject`. Le durcissement se pilote avec la variable `DMARC_MINIMUM_POLICY` du workflow de certification.

---

# 2. Éléments déjà implémentés dans le dépôt

Ces éléments existent déjà dans le code et constituent la base de production. Ils ne dispensent pas des vérifications externes Brevo/DNS/Firebase décrites plus bas.

## 2.1 Certification Brevo automatisée

Le workflow :

```text
.github/workflows/brevo-production-certification.yml
```

est prévu pour :

- tester le backend email ;
- tester Brevo depuis le runtime Firebase déployé ;
- récupérer et valider les credentials depuis Google Secret Manager ;
- valider la clé Brevo via `/v3/account` ;
- configurer/vérifier le webhook transactionnel ;
- configurer/vérifier le webhook entrant ;
- vérifier la délégation DNS du domaine entrant ;
- réparer/certifier le domaine, le sender et le webhook ;
- envoyer un email canari réel ;
- attendre la confirmation `delivered` dans Firestore ;
- tester le flux entrant `contact@ilipresto.fr` ;
- archiver les preuves ;
- publier un statut GitHub `quality/brevo-production` sur le commit déployé.

**À conserver comme source principale de certification technique.**

---

## 2.2 Audit domaine / sender / webhook / E2E

Le script :

```text
functions/scripts/brevo_production_audit.mjs
```

contrôle déjà notamment :

- `domain.verified` ;
- `domain.authenticated` ;
- l’état des enregistrements DNS ;
- la présence/validation DMARC ;
- l’existence du sender ;
- l’état actif du sender ;
- l’existence du webhook transactionnel ;
- l’unicité du webhook ;
- l’authentification Bearer ;
- la liste complète des événements ;
- l’acceptation de l’email canari par Brevo ;
- la réception du statut `delivered` via webhook.

Le mode `--repair` peut créer le domaine ou le sender s’ils sont absents et demander l’authentification du domaine lorsque les DNS sont prêts.

---

## 2.3 Pipeline entrant `contact@ilipresto.fr`

Le module :

```text
functions/src/modules/email/inbound_contact.ts
```

prévoit déjà :

```text
contact@ilipresto.fr
        ↓
contact@inbound.ilipresto.fr
        ↓
Brevo inbound parsing
        ↓
handleInboundContactEmailWebhook
        ↓
Firestore adminInboundEmails
        ↓
Administration iliprestō
```

Le webhook entrant :

- accepte uniquement `POST` ;
- limite la taille du payload ;
- vérifie l’authentification/signature via le provider ;
- filtre les destinataires ;
- déduplique les messages ;
- stocke expéditeur, sujet, corps, aperçu, pièces jointes métadonnées et score spam ;
- conserve le statut lu/non lu ;
- protège l’accès aux fonctions d’administration par rôle `admin` / `superadmin`.

---

## 2.4 Runbook incident

Le fichier :

```text
functions/docs/BREVO_INCIDENT_RUNBOOK.md
```

couvre déjà :

- erreurs d’envoi ;
- erreurs 401/403/429/5xx ;
- échecs de signature webhook ;
- hausse des bounces/plaintes ;
- latence de file d’attente ;
- rotation des secrets ;
- reprise après incident.

## 2.5 Certification DNS, seuils et hygiène des destinataires

Ajoutés au dépôt pour que ces contrôles ne dépendent plus d'une vérification manuelle :

| Contrôle | Script | Commande locale |
|---|---|---|
| SPF/DKIM/DMARC réellement publiés sur le DNS public | `functions/scripts/check_brevo_sender_dns.mjs` | `npm --prefix functions run brevo:dns:sender` |
| MX inbound Brevo | `functions/scripts/check_brevo_inbound_dns.mjs` | `npm --prefix functions run brevo:dns:inbound` |
| Seuils de délivrabilité sur 30 jours | `functions/scripts/brevo_deliverability_report.mjs` | `npm --prefix functions run brevo:deliverability` |
| Cohérence bloqués Brevo ↔ `email_suppressions` et absence de boucle d'envoi | `functions/scripts/brevo_suppression_hygiene.mjs` | `npm --prefix functions run brevo:suppressions` |

Les règles évaluées sont testées unitairement (`functions/src/modules/email/certification/`) et les quatre scripts sont branchés dans `quality/brevo-production`, avec archivage des rapports JSON dans l'artifact de certification.

Le contrôle DNS interroge le DNS public, pas le statut auto-déclaré par Brevo : il détecte un enregistrement supprimé, dupliqué, ou publié avec une valeur divergente. Sans `BREVO_API_KEY`, DKIM n'est pas vérifiable ; utiliser `--skip-dkim` pour un contrôle local partiel qui, par construction, ne certifie pas le domaine.

---

# 3. Travaux restant à certifier dans le compte Brevo

## 3.1 Compte Brevo

- [ ] Vérifier que le compte Brevo utilisé est bien le compte de production iliprestō.
- [ ] Vérifier le nom d’organisation / identité de marque affiché dans Brevo.
- [ ] Vérifier qu’aucun ancien environnement de test ne peut être confondu avec la production.
- [ ] Vérifier le niveau de quota / limite d’envoi du compte.
- [ ] Vérifier que les alertes de quota sont configurées si Brevo le permet.
- [ ] Vérifier qu’aucune restriction de compte n’empêche les envois transactionnels.

### Critère de sortie

- [ ] Le compte accepte un appel `GET /v3/account` avec la clé de production.

> Le relevé du 25 août 2026 (section 1 bis) confirme un compte Brevo actif, plan Starter payant et relais SMTP activé, mais il a été obtenu via le connecteur MCP : il ne prouve pas que la clé stockée dans Secret Manager est la même. Cette case reste à cocher par `quality/brevo-production`, qui interroge `/v3/account` avec la credential de production.

---

# 4. Domaine d’envoi `ilipresto.fr`

## 4.1 Vérification Brevo

Dans Brevo, contrôler le domaine :

```text
ilipresto.fr
```

- [ ] Domaine présent.
- [ ] Domaine `verified=true`.
- [ ] Domaine `authenticated=true`.
- [ ] Tous les enregistrements DNS demandés par Brevo sont au vert.

## 4.2 SPF

- [ ] Vérifier l’enregistrement SPF réel de `ilipresto.fr`.
- [ ] Vérifier qu’il n’existe pas plusieurs SPF TXT concurrents.
- [ ] Vérifier que Brevo est autorisé dans le SPF utilisé.

## 4.3 DKIM

- [ ] Vérifier tous les enregistrements DKIM fournis par Brevo.
- [ ] Vérifier qu’ils sont publiés chez le DNS actuel d’ilipresto.fr.
- [ ] Vérifier que Brevo les marque comme valides.

## 4.4 DMARC

- [ ] Vérifier `_dmarc.ilipresto.fr`.
- [ ] Vérifier que la syntaxe DMARC est valide.
- [ ] Vérifier que les rapports DMARC sont envoyés vers une boîte réellement surveillée si `rua`/`ruf` sont utilisés.
- [ ] Commencer par une politique adaptée à la phase de déploiement puis durcir progressivement après validation.

### Critère de sortie

Le script :

```bash
node functions/scripts/brevo_production_audit.mjs --domain ilipresto.fr ...
```

doit retourner :

```text
PASS domain.verified
PASS domain.authenticated
PASS domain.dns_records
PASS domain.dmarc
```

et le contrôle DNS public :

```bash
npm --prefix functions run brevo:dns:sender
```

doit retourner :

```text
SPF   PASS v=spf1 include:spf.brevo.com -all
DKIM  PASS
DMARC PASS
BREVO_SENDER_DNS_RESULT={"ok":true,...}
```

---

# 5. Expéditeur et Reply-To

Configuration cible :

```text
From: iliprestō <noreply@ilipresto.fr>
Reply-To: contact@ilipresto.fr
```

- [ ] `noreply@ilipresto.fr` existe dans Brevo. — **absent au 25 août 2026** (section 1 bis).
- [ ] Le sender est actif.
- [ ] Le sender utilise le domaine authentifié `ilipresto.fr`.
- [ ] Aucun sender de test ne reste sélectionné en production. — **`sahai.stephane@gmail.com` est aujourd'hui le seul sender du compte** (section 1 bis).
- [ ] Tous les emails transactionnels utilisent `contact@ilipresto.fr` comme Reply-To lorsqu’une réponse utilisateur est pertinente.
- [ ] Le nom visible est cohérent : `iliprestō`.

### Critère de sortie

```text
PASS sender.exists
PASS sender.active
```

---

# 6. Secrets Firebase / Google Secret Manager

Secrets de production attendus :

```text
BREVO_API_KEY
BREVO_WEBHOOK_SECRET
```

- [ ] `BREVO_API_KEY` existe dans Secret Manager.
- [ ] La version `latest` de `BREVO_API_KEY` fonctionne réellement.
- [ ] `BREVO_WEBHOOK_SECRET` existe dans Secret Manager.
- [ ] Aucun secret Brevo n’est présent dans Flutter.
- [ ] Aucun secret Brevo n’est présent dans Firebase Hosting.
- [ ] Aucun secret Brevo n’est versionné dans GitHub.
- [ ] Aucun secret n’est imprimé dans les logs CI.
- [ ] Vérifier les droits IAM des comptes pouvant lire les secrets.
- [ ] Restreindre l’accès aux secrets aux runtimes et administrateurs nécessaires.

## 6.1 Legacy credential

Le workflow connaît encore la clé historique :

```text
EMAIL_PROVIDER_API_KEY
```

- [ ] Vérifier si cette clé legacy est encore nécessaire.
- [ ] Lorsque `BREVO_API_KEY` est stable et certifiée, supprimer progressivement la dépendance au secret legacy.
- [ ] Révoquer les anciennes clés Brevo devenues inutiles.

### Critère de sortie

Une seule credential principale valide et documentée doit être utilisée par le runtime :

```text
BREVO_API_KEY
```

---

# 7. Webhook transactionnel Brevo

URL cible :

```text
https://europe-west1-presto-app-74abe.cloudfunctions.net/handleEmailProviderWebhook
```

- [ ] Un seul webhook transactionnel correspondant à cette URL.
- [ ] Type `transactional`.
- [ ] Authentification Bearer active.
- [ ] Secret identique à `BREVO_WEBHOOK_SECRET` côté Firebase.
- [ ] Pas d’ancien webhook test/duplicate actif.

## 7.1 Événements requis

Le webhook doit couvrir au minimum :

- [ ] `sent` ou équivalent `request` selon Brevo.
- [ ] `delivered`.
- [ ] `hardBounce`.
- [ ] `softBounce`.
- [ ] `blocked`.
- [ ] `spam`.
- [ ] `invalid`.
- [ ] `deferred`.
- [ ] `click`.
- [ ] `opened`.
- [ ] `uniqueOpened`.
- [ ] `unsubscribed`.

### Critère de sortie

```text
PASS webhook.exists
PASS webhook.single
PASS webhook.auth_bearer
PASS webhook.events
```

---

# 8. Test E2E sortant réel

Adresse canari recommandée :

```text
contact@ilipresto.fr
```

ou une boîte de test contrôlée explicitement.

- [ ] Déclencher la certification Brevo via GitHub Actions.
- [ ] Vérifier que Brevo accepte le message et renvoie un `messageId`.
- [ ] Vérifier la réception effective du message.
- [ ] Vérifier le webhook `delivered`.
- [ ] Vérifier que `email_logs.provider_message_id` contient le message correspondant.
- [ ] Vérifier l’absence de `bounced`, `complained`, `dropped` ou `failed`.

### Critère de sortie

```text
PASS e2e.provider_accepted
PASS e2e.webhook_delivery
```

---

# 9. Réception des emails sur `contact@ilipresto.fr`

## 9.1 Domaine inbound

Domaine technique cible :

```text
inbound.ilipresto.fr
```

Alias technique cible :

```text
contact@inbound.ilipresto.fr
```

- [ ] Le domaine entrant existe dans Brevo.
- [ ] Les enregistrements MX demandés par Brevo sont publiés.
- [ ] La délégation DNS est réellement propagée publiquement.
- [ ] `check_brevo_inbound_dns.mjs` est vert.

> **Anomalie constatée le 25 août 2026.** `inbound.ilipresto.fr` publie un unique MX `inbound1.sendinblue.com.ilipresto.fr` : le point final a été omis dans l'interface LWS, qui a donc suffixé le domaine. La cible n'existe pas et aucun email ne peut être reçu. Le second MX (`inbound2.sendinblue.com`) est également absent. Republier les deux enregistrements **avec** le point final terminal.

## 9.2 Routage de la boîte publique

- [ ] Vérifier comment `contact@ilipresto.fr` est géré chez LWS / fournisseur mail.
- [ ] Vérifier que les emails destinés à `contact@ilipresto.fr` sont redirigés/copiés vers le mécanisme entrant Brevo sans casser la boîte principale.
- [ ] Éviter toute boucle de forwarding.
- [ ] Vérifier que le `Reply-To` d’un email entrant est conservé correctement.

## 9.3 Webhook entrant

URL cible :

```text
https://europe-west1-presto-app-74abe.cloudfunctions.net/handleInboundContactEmailWebhook
```

- [ ] Webhook entrant créé dans Brevo.
- [ ] Authentification Bearer active.
- [ ] Le secret correspond au secret attendu côté Firebase.
- [ ] Test avec un email envoyé depuis une adresse externe réelle.
- [ ] Le webhook retourne HTTP 200.
- [ ] `accepted >= 1` pour un message destiné à la boîte iliprestō.

## 9.4 Firestore

Collection attendue :

```text
adminInboundEmails
```

- [ ] Le message apparaît dans Firestore.
- [ ] `sender_email` correct.
- [ ] `subject` correct.
- [ ] `body_markdown` correct.
- [ ] `received_at` correct.
- [ ] Les métadonnées pièces jointes sont présentes lorsqu’il y en a.
- [ ] `spam_score` est renseigné lorsque Brevo le fournit.
- [ ] `is_read` fonctionne.
- [ ] Les messages dupliqués ne créent pas plusieurs documents.

## 9.5 Sécurité administration

- [ ] Les fonctions de lecture de la boîte entrante exigent authentification.
- [ ] Seuls `admin` / `superadmin` ont accès.
- [ ] App Check est activé lorsque la stratégie App Check globale permet sa réactivation sans casser la production.
- [ ] Aucune donnée de boîte admin n’est accessible à un utilisateur standard.

### Critère de sortie

Le test :

```text
functions/scripts/brevo_inbound_contact_e2e.mjs
```

doit réussir entièrement.

---

# 10. Templates transactionnels

Créer un inventaire exhaustif des emails réellement envoyés par iliprestō.

Exemples à vérifier selon les fonctionnalités actives :

- [ ] vérification d’adresse email ;
- [ ] sécurité / changement de compte ;
- [ ] notifications importantes ;
- [ ] messages liés aux annonces ;
- [ ] modération ;
- [ ] avis ;
- [ ] support / contact ;
- [ ] abonnement iliprestō+ / ilipro lorsque la monétisation sera activée ;
- [ ] emails administratifs nécessaires.

Pour chaque template :

- [ ] sujet clair ;
- [ ] nom `iliprestō` cohérent ;
- [ ] From correct ;
- [ ] Reply-To correct ;
- [ ] HTML responsive ;
- [ ] version texte ou contenu dégradable ;
- [ ] aucun lien vers un ancien domaine Firebase lorsque `ilipresto.fr` doit être utilisé ;
- [ ] aucune donnée personnelle non nécessaire ;
- [ ] liens juridiques corrects si requis ;
- [ ] rendu Gmail contrôlé ;
- [ ] rendu Outlook contrôlé ;
- [ ] rendu mobile contrôlé ;
- [ ] caractères `ō`, accents et apostrophes correctement encodés.

---

# 11. Délivrabilité

- [ ] Effectuer un test Gmail réel.
- [ ] Effectuer un test Outlook/Hotmail réel.
- [ ] Vérifier absence de spam sur les tests normaux.
- [ ] Vérifier SPF pass dans les headers reçus.
- [ ] Vérifier DKIM pass.
- [ ] Vérifier DMARC pass.
- [ ] Vérifier l’alignement du domaine visible avec `ilipresto.fr`.
- [ ] Contrôler le ratio delivered/sent.
- [ ] Contrôler hard bounce.
- [ ] Contrôler soft bounce.
- [ ] Contrôler blocked.
- [ ] Contrôler complaint/spam.
- [ ] Contrôler deferred.

## Seuils

Seuils internes définis dans `functions/src/modules/email/certification/deliverability.ts`, source unique partagée par l'alerting runtime (`syncEmailAnalytics`) et par la certification CI :

| Métrique | Seuil | Sens |
|---|---|---|
| Volume minimal évalué | 50 envois | En dessous, les taux ne sont pas appliqués (l'échantillon est seulement reporté) |
| Taux de livraison | ≥ 95 % | Sous ce niveau, la certification échoue |
| Hard bounce | ≤ 2 % | |
| Soft bounce | ≤ 5 % | |
| Bounce total | ≤ 5 % | |
| Bloqués | ≤ 2 % | |
| Plaintes spam | ≤ 0,1 % | Marge volontaire sous les 0,3 % sanctionnés par Gmail et Yahoo |
| Adresses invalides | ≤ 1 % | |
| Différés | ≤ 10 % | |

Chaque seuil est surchargeable par variable d'environnement (`BREVO_MAX_HARD_BOUNCE_RATE`, `BREVO_MAX_COMPLAINT_RATE`, …) pour un ajustement temporaire documenté, sans modification de code.

- [x] Définir des seuils internes d’alerte pour bounce et complaint.
- [x] Définir le comportement lorsqu’un seuil est dépassé : `quality/brevo-production` échoue et le rapport `quality/brevo-deliverability.json` nomme la ou les métriques en cause.
- [ ] Documenter la suspension automatique ou manuelle des flux non essentiels en cas d’incident.

---

# 12. Suppressions et hygiène des destinataires

Collection existante à surveiller :

```text
email_suppressions
```

- [ ] Vérifier qu’un hard bounce entraîne la protection attendue contre les renvois inutiles.
- [ ] Vérifier le traitement des plaintes spam.
- [ ] Vérifier le traitement des adresses invalides.
- [ ] Vérifier les règles de réactivation éventuelle.
- [x] Empêcher les boucles d’envoi vers une adresse déjà supprimée.
- [ ] Vérifier les règles RGPD applicables aux données conservées dans les logs/suppressions.

> **Correctif appliqué.** Le webhook fournisseur écrit la suppression sur l'adresse normalisée en minuscules, alors que l'enqueue interrogeait la liste avec la casse brute de l'événement : un destinataire enregistré sous une autre casse (`User@Gmail.com`) continuait à recevoir des emails malgré un hard bounce ou une plainte. L'enqueue et `suppressRecipient` normalisent désormais la clé de la même façon, avec repli sur les documents historiques.

Le script `brevo_suppression_hygiene.mjs` certifie en continu trois points : chaque contact bloqué chez Brevo pour un motif bloquant possède une suppression active en base, aucune suppression n'est restée inactive alors que Brevo bloque l'adresse, et aucun envoi n'est parti après la date de suppression.

---

# 13. Files d’attente, retries et idempotence

- [ ] Vérifier qu’un échec temporaire 5xx provoque bien un retry contrôlé.
- [ ] Vérifier le comportement HTTP 429.
- [ ] Vérifier la limite de retry.
- [ ] Vérifier la dead-letter / état terminal si le retry échoue définitivement.
- [ ] Vérifier que deux retries ne provoquent pas deux emails identiques.
- [ ] Conserver un identifiant d’idempotence pour les envois critiques.
- [ ] Vérifier qu’un webhook Brevo rejoué ne crée pas de doublon logique.

---

# 14. Observabilité production

Collections à surveiller :

```text
email_jobs
email_logs
email_provider_webhooks
email_suppressions
adminInboundEmails
```

- [ ] Tableau/outil admin permettant de voir les erreurs récentes.
- [ ] Nombre d’emails `sent`.
- [ ] Nombre d’emails `delivered`.
- [ ] Bounces.
- [ ] Blocked.
- [ ] Complaints.
- [ ] Retries.
- [ ] Latence moyenne d’envoi.
- [ ] Backlog `email_jobs`.
- [ ] Échecs de signature webhook.
- [ ] Nombre d’emails entrants non lus.

## Alertes minimales

- [ ] échec de signature webhook inhabituel ;
- [ ] taux de bounce anormal ;
- [ ] complaint/spam ;
- [ ] accumulation de jobs ;
- [ ] erreurs Brevo 401/403 ;
- [ ] erreurs Brevo 429 ;
- [ ] erreurs Brevo 5xx prolongées ;
- [ ] échec de certification Brevo après un déploiement `main`.

---

# 15. Sécurité

- [ ] Aucune clé API dans le client Flutter.
- [ ] Aucune clé API dans le Web build.
- [ ] Aucune clé API dans GitHub.
- [ ] Aucune clé API dans un artifact CI.
- [ ] Tous les secrets sont masqués dans GitHub Actions.
- [ ] Rotation de `BREVO_API_KEY` documentée.
- [ ] Rotation de `BREVO_WEBHOOK_SECRET` documentée.
- [ ] Révocation immédiate des secrets obsolètes.
- [ ] Droits Brevo réduits au strict nécessaire lorsque Brevo permet de les granulariser.
- [ ] Accès au compte Brevo protégé par MFA pour les administrateurs.
- [ ] Liste des administrateurs Brevo revue périodiquement.

---

# 16. RGPD / conformité email

- [ ] Identifier les emails strictement transactionnels.
- [ ] Séparer les emails marketing des emails transactionnels.
- [ ] Ne pas envoyer de campagne marketing pendant la bêta si elle n’est pas nécessaire.
- [ ] Vérifier la base légale applicable avant tout marketing.
- [ ] Ajouter désinscription aux flux qui l’exigent.
- [ ] Ne pas permettre la désinscription d’un message strictement nécessaire au fonctionnement/sécurité lorsque la loi ne l’impose pas, tout en conservant une conception proportionnée.
- [ ] Définir la durée de conservation des logs Brevo/Firebase.
- [ ] Vérifier que la politique de confidentialité iliprestō décrit correctement le traitement email réel.
- [ ] Vérifier la cohérence avec Google Data Safety / Apple App Privacy lorsque les emails et identifiants y sont déclarés.

---

# 17. Certification GitHub obligatoire

Workflow :

```text
Certify Brevo Production
```

Statut attendu :

```text
quality/brevo-production = success
```

- [ ] Déploiement `main` réussi.
- [ ] Runtime canary réussi.
- [ ] Credential Brevo validée.
- [ ] Webhook transactionnel validé.
- [ ] Webhook entrant validé.
- [ ] DNS inbound validé.
- [ ] Audit domaine/sender réussi.
- [ ] E2E sortant réussi.
- [ ] E2E entrant réussi.
- [ ] Artifact de certification généré.
- [ ] Artifact conservé 90 jours.
- [ ] Statut GitHub publié sur le SHA réellement déployé.

## Preuve attendue

Artifact :

```text
brevo-production-certification-<SHA>-<RUN_ID>
```

Contenu attendu :

```text
quality/brevo-production-certification.json
quality/brevo-runtime-canary.log
quality/brevo-inbound-dns.log
quality/brevo-inbound-e2e.log
```

---

# 18. Test manuel final avant déclaration 100 %

Effectuer au minimum ce scénario :

1. [ ] Déployer `main`.
2. [ ] Attendre le workflow de certification Brevo.
3. [ ] Vérifier `quality/brevo-production = success`.
4. [ ] Envoyer un email transactionnel réel depuis iliprestō vers Gmail.
5. [ ] Vérifier la réception.
6. [ ] Vérifier SPF/DKIM/DMARC dans les headers Gmail.
7. [ ] Vérifier `delivered` dans `email_logs`.
8. [ ] Envoyer un email externe vers `contact@ilipresto.fr`.
9. [ ] Vérifier son arrivée dans la boîte mail normale si celle-ci doit être conservée.
10. [ ] Vérifier sa copie/réception dans `adminInboundEmails`.
11. [ ] Vérifier l’affichage côté administration iliprestō.
12. [ ] Marquer le message comme lu et vérifier la persistance.
13. [ ] Envoyer un second message avec une pièce jointe et vérifier les métadonnées.
14. [ ] Tester un payload webhook invalide et vérifier HTTP 401.
15. [ ] Vérifier qu’un compte utilisateur non-admin ne peut pas consulter la boîte entrante.
16. [ ] Vérifier l’absence de secrets Brevo dans les logs.

---

# 19. ChatGPT ↔ Brevo MCP

Architecture cible :

```text
ChatGPT
   ↓
MCP officiel Brevo
https://mcp.brevo.com/v1/brevo/mcp
   ↓
Compte Brevo iliprestō
```

## Préparation déjà réalisée dans le repo

Documentation :

```text
docs/production/CHATGPT_BREVO_MCP.md
```

## Travaux restants

- [ ] Disposer d’un plan ChatGPT permettant une app MCP personnalisée.
- [ ] Générer un token MCP Brevo dédié.
- [ ] Ne jamais copier ce token dans le repo ou les conversations.
- [ ] Créer l’app `Brevo iliprestō` dans ChatGPT web.
- [ ] Endpoint : `https://mcp.brevo.com/v1/brevo/mcp`.
- [ ] Configurer l’authentification Bearer.
- [ ] Analyser les outils exposés.
- [ ] Vérifier d’abord senders/domaines en lecture seule.
- [ ] Vérifier ensuite les événements transactionnels.
- [ ] Vérifier les templates.
- [ ] Vérifier les webhooks.
- [ ] Autoriser une action d’écriture faible risque uniquement après validation.
- [ ] Conserver une confirmation explicite pour les envois, modifications massives, domaines, senders et webhooks.

**Important : la partie MCP ne doit jamais remplacer le pipeline applicatif Firebase → Brevo.**

---

# 20. Nettoyage final

Après certification complète :

- [ ] Révoquer toutes les anciennes clés Brevo inutiles.
- [ ] Supprimer les webhooks de test/dupliqués.
- [ ] Supprimer les senders de test inutiles.
- [ ] Vérifier qu’aucun ancien domaine Firebase n’est utilisé comme URL publique dans les templates.
- [ ] Supprimer les configurations temporaires utilisées durant le diagnostic.
- [ ] Vérifier que les scripts de réparation ne cachent pas un état externe incorrect.
- [ ] Conserver uniquement les chemins de production documentés.

---

# 21. Ordre d’exécution recommandé

## P0 — bloquants production

- [ ] **Remplacer `BREVO_API_KEY`** : la clé actuelle en Secret Manager est rejetée par Brevo en HTTP 401 (run [#54](https://github.com/stef25fwi/presto_app/actions/runs/32893628913), cf. 1 bis) — bloquant absolu, à traiter avant tout le reste de cette liste.
- [ ] Valider `BREVO_WEBHOOK_SECRET`.
- [ ] Publier le SPF Brevo (aucun SPF n'existe aujourd'hui, cf. 1 bis).
- [ ] Publier les DKIM Brevo (aucun DKIM n'existe aujourd'hui, cf. 1 bis).
- [ ] Ajouter `rua` au DMARC et aligner la politique sur la phase en cours.
- [ ] Authentifier `ilipresto.fr`.
- [ ] Activer `noreply@ilipresto.fr` et retirer le sender de test `sahai.stephane@gmail.com`.
- [ ] Certifier le webhook transactionnel.
- [ ] Réussir l’E2E sortant.
- [ ] Corriger les MX de `inbound.ilipresto.fr` (point final manquant, second MX absent, cf. 1 bis).
- [ ] Réussir l’E2E entrant sur `contact@ilipresto.fr`.

## P1 — qualité production

- [ ] Finaliser tous les templates transactionnels.
- [ ] Tester Gmail/Outlook/mobile.
- [ ] Mettre les alertes de délivrabilité.
- [ ] Valider suppression/bounce/complaint.
- [ ] Valider retries/idempotence.
- [ ] Vérifier observabilité admin.

## P2 — conformité et exploitation

- [ ] Finaliser conservation RGPD.
- [ ] Revoir droits IAM.
- [ ] Revoir administrateurs Brevo + MFA.
- [ ] Documenter rotation des clés.
- [ ] Exécuter un exercice incident avec le runbook.

## P3 — administration IA

- [ ] Activer ChatGPT ↔ Brevo MCP quand le plan ChatGPT le permet.
- [ ] Audits lecture seule validés.
- [ ] Écriture contrôlée validée.

---

# 22. Tableau de certification finale

| Domaine | Critère | Statut |
|---|---|---|
| Compte Brevo | API `/v3/account` valide | ⬜ |
| Domaine | `ilipresto.fr` vérifié | ⬜ |
| Domaine | `ilipresto.fr` authentifié | ⬜ |
| DNS | SPF valide (publié, unique, Brevo autorisé) | ⬜ |
| DNS | DKIM valide (publié et conforme aux valeurs Brevo) | ⬜ |
| DNS | DMARC valide (syntaxe, politique, `rua` surveillée) | ⬜ |
| DNS | `BREVO_SENDER_DNS_RESULT` à `ok:true` | ⬜ |
| Sender | `noreply@ilipresto.fr` actif | ⬜ |
| Reply-To | `contact@ilipresto.fr` | ⬜ |
| Secret | `BREVO_API_KEY` valide | ⬜ |
| Secret | `BREVO_WEBHOOK_SECRET` valide | ⬜ |
| Webhook | transactionnel unique + Bearer | ⬜ |
| Webhook | événements complets | ⬜ |
| Sortant | canari accepté | ⬜ |
| Sortant | canari delivered | ⬜ |
| Inbound | DNS `inbound.ilipresto.fr` valide | ⬜ |
| Inbound | webhook entrant valide | ⬜ |
| Inbound | email réel dans `adminInboundEmails` | ⬜ |
| Admin | accès limité admin/superadmin | ⬜ |
| Délivrabilité | Gmail validé | ⬜ |
| Délivrabilité | Outlook validé | ⬜ |
| Délivrabilité | Seuils internes respectés sur 30 jours | ⬜ |
| Hygiène | Bloqués Brevo couverts par `email_suppressions` | ⬜ |
| Hygiène | Aucun envoi après suppression | ⬜ |
| Observabilité | logs + suppressions + alertes | ⬜ |
| CI | `quality/brevo-production = success` | ⬜ |
| Preuves | artifact E2E archivé | ⬜ |
| Sécurité | secrets/permissions/MFA validés | ⬜ |
| RGPD | traitement email documenté | ⬜ |
| MCP | ChatGPT ↔ Brevo activé si éligible | ⬜ |

---

# 23. Condition de clôture

Le chantier Brevo est déclaré **TERMINÉ À 100 %** uniquement si :

```text
quality/brevo-production = success
```

**et** que tous les contrôles externes non vérifiables uniquement depuis le code — Brevo, DNS, réception réelle, délivrabilité Gmail/Outlook, droits d’accès et secrets — ont été validés avec une preuve.

La présence du code, des scripts ou des workflows n’est pas considérée à elle seule comme une certification de production.
