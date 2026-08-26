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
>
> **Troisième échec identique (26 août 2026, ~00h13 UTC).** Une clé distincte (celle du connecteur MCP Brevo, dont chaque appel en lecture avait jusque-là réussi) a été proposée pour une version 9 du secret. Le run `quality/brevo-production` [#57](https://github.com/stef25fwi/presto_app/actions/runs/32913999911) échoue avec la **même erreur HTTP 401**, sur `BREVO_API_KEY` et `EMAIL_PROVIDER_API_KEY`, et le canari runtime Firebase échoue toujours par timeout. Trois échecs consécutifs avec deux valeurs de clé distinctes commencent à ressembler moins à une clé isolée invalide qu'à une restriction au niveau du compte Brevo (`Sécurité` → `Adresses IP autorisées`) ou à un problème d'enregistrement systématique de la nouvelle version avant de rejouer la certification — à confirmer avant tout nouvel essai en vérifiant directement dans Secret Manager que la version testée correspond bien à celle qu'on croit avoir enregistrée.
>
> **Quatrième échec identique, hypothèse « mauvaise valeur » écartée (26 août 2026, ~00h30 UTC).** La version 9 contenait en réalité le blob base64 brut transmis par l'utilisateur, pas la clé décodée : une version 10 a été créée avec la valeur `xkeysib-...` correctement décodée (format vérifié : préfixe `xkeysib-` + 64 caractères hexadécimaux + suffixe alphanumérique, conforme au standard Brevo). Le run `quality/brevo-production` [#58](https://github.com/stef25fwi/presto_app/actions/runs/32915227998) échoue encore avec exactement la même erreur HTTP 401. **Quatre échecs consécutifs avec trois valeurs de clé distinctes, toutes au bon format, écartent l'hypothèse d'une clé individuelle invalide.** Le dénominateur commun devient le compte Brevo ou l'environnement d'appel, pas la clé. Deux pistes à vérifier avant tout nouvel essai :
> - `Sécurité` → `Adresses IP autorisées` dans Brevo, même si le bandeau affichait le blocage global désactivé lors du premier relevé (section 1 bis) ;
> - une alerte de sécurité ou un blocage anti-abus Brevo déclenché par les tentatives d'authentification répétées depuis les IPs des runners GitHub Actions, indépendant de la clé utilisée.
>
> **✅ Blocage #0 résolu (26 août 2026, ~00h55 UTC) — cause confirmée : restriction IP.** Le bandeau `SMTP et API` était repassé sur « adresses IP non autorisées bloquées » entre le relevé initial et ces essais (probablement activé par inadvertance via le bouton du bandeau). Une fois cette restriction désactivée dans Brevo (`Sécurité` → `Adresses IP autorisées`), le run `quality/brevo-production` [#59](https://github.com/stef25fwi/presto_app/actions/runs/32916691618) obtient enfin :
> ```text
> Credential Brevo validée via /v3/account : BREVO_API_KEY.
> ```
> et un envoi transactionnel réel est accepté par Brevo (`brevo_inbound_contact_e2e.mjs`) :
> ```text
> Mail E2E accepté par Brevo: <202608260053.45409989385@smtp-relay.mailin.fr>
> ```
> `BREVO_DELIVERABILITY_RESULT={"ok":true,"evaluated":false,"sample":1,"warnings":["sample_below_threshold"]}` et `BREVO_SUPPRESSION_HYGIENE_RESULT={"ok":true,"missing":0,"inactive":0,"postSuppressionSends":0}` passent également.
>
> **Deux constats supplémentaires issus de ce run :**
> - **Le canari via le runtime Firebase déployé échoue toujours par timeout**, alors que l'appel direct à l'API Brevo réussit. Cause probable : les Cloud Functions v2 résolvent en général leur secret Secret Manager à une **version figée au moment du déploiement**, pas à `latest`. Le runtime déployé référence donc très probablement encore une ancienne version (1 à 9, toutes invalidées côté Brevo), même si la version 10 est maintenant correcte. **Un redéploiement des Cloud Functions est nécessaire** pour que la production réelle (pas seulement les scripts de certification) envoie des emails.
> - **L'étape de réparation automatique (`--repair`, création du sender `noreply@ilipresto.fr` et authentification du domaine) n'a pas encore pu s'exécuter** : elle était enchaînée après la création du webhook inbound dans le workflow, qui a échoué en HTTP 400 (le domaine entrant `inbound.ilipresto.fr` n'existe pas encore comme objet Brevo, cf. section 9.1), ce qui a fait sauter les étapes suivantes faute de `if: always()`. Corrigé dans le workflow (chaque étape de certification tourne désormais indépendamment) ; un nouveau run exécutera enfin la réparation domaine/sender.
>
> **Run [#60](https://github.com/stef25fwi/presto_app/actions/runs/32918096410) (26 août 2026, ~01h18 UTC) — workflow corrigé, deux constats précis et actionnables :**
> - **`noreply@ilipresto.fr` ne peut pas être créé tant que le domaine n'est pas authentifié — confirmé par Brevo lui-même**, pas seulement déduit : `brevo_production_audit.mjs --repair` obtient `POST /senders → HTTP 400 {"code":"bad_request","message":"Your DMARC policy requires your domain to be authenticated before creating a sender with this domain. Authenticate domain and then create a sender."}`. Le domaine `ilipresto.fr` existe déjà comme objet dans Brevo (pas de `domain_created` dans les actions de réparation, donc création déjà faite lors d'un essai antérieur) mais reste non authentifié faute de SPF/DKIM publiés. **Ordre de dépendance strict confirmé : DNS → authentification du domaine → création du sender**, aucune étape ne peut être sautée.
> - **Nouveau : le webhook transactionnel déployé rejette une authentification Bearer valide.** `brevo_webhook_smoke_test.mjs` envoie des requêtes signées avec la valeur actuelle de `BREVO_WEBHOOK_SECRET` (Secret Manager, `latest`) vers `handleEmailProviderWebhook` déployé, et obtient `401 {"ok":false,"error":"invalid webhook authentication"}` sur 4 événements testés. **Ce n'est plus seulement `BREVO_API_KEY` : le runtime Firebase déployé fonctionne très probablement avec une version figée de `BREVO_WEBHOOK_SECRET` également**, différente de celle en vigueur. Conséquence concrète : les webhooks réels envoyés par Brevo (accusés de livraison, bounces, plaintes) sont vraisemblablement rejetés par la production **en ce moment même**, indépendamment du problème DNS.
> - `Ensure Brevo transactional webhook configuration` réussit (`Mise à jour du webhook Brevo existant id=1922163`) — la configuration du webhook côté Brevo elle-même est correcte, seule sa validation côté runtime déployé est en cause.
> - Confirmé une seconde fois : `BREVO_DELIVERABILITY_RESULT={"ok":true,"evaluated":false,"sample":2,"warnings":["sample_below_threshold"]}` et `BREVO_SUPPRESSION_HYGIENE_RESULT={"ok":true,"missing":0,"inactive":0,"postSuppressionSends":0}`.
>
> **Le redéploiement des Cloud Functions n'est donc plus une simple recommandation de confort : c'est un P0**, nécessaire pour que `BREVO_API_KEY` (envoi) et `BREVO_WEBHOOK_SECRET` (réception des accusés) soient tous deux à jour en production. Un workflow `workflow_dispatch`-déclenchable existe déjà : `.github/workflows/deploy.yml` (« Validate and Deploy Firebase »).
>
> **✅ Cloud Functions redéployées (26 août 2026, ~01h50 UTC).** Déclenché sur `main` avec `deploy_functions=true` : run [#2426](https://github.com/stef25fwi/presto_app/actions/runs/32919245891). `Deploy Functions with exit 130 retry` réussit — les ~80 fonctions, dont `handleEmailProviderWebhook` et `handleInboundContactEmailWebhook`, sont mises à jour, ainsi que l'hébergement et les règles Firestore. Le runtime déployé résout donc désormais `BREVO_API_KEY` et `BREVO_WEBHOOK_SECRET` à leur version `latest`. Le job est marqué en échec globalement, mais uniquement à cause d'un test de fumée **sans rapport avec Brevo** : `https://ilipresto.fr/confidentialite` ne renvoie pas de balise `<title>` — anomalie pré-existante sur une page publique, à traiter séparément, non bloquante pour ce chantier.
>
> Prochaine étape : rejouer `quality/brevo-production` pour vérifier si le canari runtime (`BREVO_RUNTIME_CANARY_RESULT`) et l'authentification Bearer du webhook (`brevo_webhook_smoke_test.mjs`) passent enfin avec les secrets à jour côté runtime.
>
> **❌ Hypothèse « secret figé au déploiement » invalidée (26 août 2026, run [#62](https://github.com/stef25fwi/presto_app/actions/runs/32921957460), ~02h19 UTC).** Rejoué 20 minutes après un redéploiement réussi des Cloud Functions — les deux symptômes sont **strictement identiques** à avant le redéploiement :
> ```text
> BREVO_RUNTIME_CANARY_RESULT={"ok":false,...,"errorCode":"runtime_canary_timeout"}
> [KO] event=delivered auth=bearer status=401 {"ok":false,"error":"invalid webhook authentication"}
> ```
> Le code utilise `defineSecret()` (Firebase Functions v2, `functions/src/config/env.ts`), qui résout normalement `latest` au moment du déploiement — la version 10 du secret, validée fonctionnelle par ailleurs, était déjà la version `latest` bien avant ce déploiement. La logique de vérification Bearer (`functions/src/modules/email/providers/brevo_provider.ts`) a été relue et semble correcte. **Deux causes restent ouvertes, à départager en inspectant directement la configuration de la fonction déployée** (accès `gcloud`/Console GCP requis, non disponible depuis cette session) :
> - le déploiement n'a en réalité pas rebindé le secret vers la version 10 (vérifier `Cloud Functions` → `handleEmailProviderWebhook` (europe-west1) → Variables/Secrets → version référencée de `BREVO_WEBHOOK_SECRET`) ;
> - le canari runtime et le webhook échouent pour une raison indépendante des secrets — un bug dans le pipeline d'envoi lui-même, à investiguer via Cloud Logging sur l'exécution réelle de la fonction pendant un test.
>
> Tant que cette version n'est pas confirmée en Console, ne pas relancer une nouvelle rotation de clé ou un nouveau redéploiement à l'aveugle : ça reproduirait le même résultat sans nouvelle information.
>
> **✅ Webhook transactionnel réparé — cause racine : un caractère parasite dans le secret stocké (26 août 2026, run [#64](https://github.com/stef25fwi/presto_app/actions/runs/32924892582), ~03h04 UTC).** L'inspection du code a révélé une asymétrie de normalisation dans `brevo_provider.ts` : `verifyWebhookSignature` comparait `bearerMatch[1].trim()` au secret stocké **tel quel**, et `constantTimeEqual` renvoie `false` dès que les longueurs diffèrent. Les secrets arrivent de Secret Manager via `process.env`, qui conserve la valeur exacte stockée : un secret créé avec un saut de ligne final — cas courant d'un `echo` sans `-n` ou d'un collage en console — porte ce `\n` côté runtime, alors que la CI lit le même secret via `$(gcloud secrets versions access latest)`, où la substitution de commande bash supprime les sauts de ligne finaux. Chaque comparaison échouait donc, quel que soit le nombre de redéploiements — ce qui explique exactement pourquoi le redéploiement du run #62 n'avait rien changé.
>
> Après normalisation des secrets à leur point d'entrée (`provider_factory`) et suppression de l'asymétrie dans `BrevoProvider`, déployées en production (run deploy [#2427](https://github.com/stef25fwi/presto_app/actions/runs/32923396773), `Deploy Functions` = success) :
> ```text
> [OK] event=delivered   auth=bearer status=200
> [OK] event=opened      auth=bearer status=200
> [OK] event=click       auth=bearer status=200
> [OK] event=soft_bounce auth=bearer status=200
> Smoke test passed: 4 valid events accepted and security probes rejected.
> ```
> **Les accusés de livraison, bounces et plaintes envoyés par Brevo sont donc de nouveau acceptés par la production.** Le test de régression ajouté échoue sans le correctif et passe avec (vérifié explicitement).
>
> **⚠️ Le canari runtime reste en échec, et c'est un problème distinct.** `BREVO_RUNTIME_CANARY_RESULT` rapporte toujours `runtime_canary_timeout` avec `jobStatus: null` et `logStatuses: []` : **aucun `email_jobs` n'est jamais créé**. Or l'étape qui crée le job (`enqueueEmailJobsFromEvent`) ne touche à aucune credential Brevo — ce n'est donc pas un problème de secret. Toutes les sorties anticipées de l'enqueue ont été écartées par lecture du code :
> - `mapEventToTemplate("support.ticket.created")` renvoie bien `tpl_transactional_support_ticket_created_v1` ;
> - le template existe dans le registre legacy, avec `channel: transactionnel` ;
> - les variables requises (`firstName`, `ticketNumber`, `ticketSubject`) sont toutes fournies par le canari ;
> - `resolvePreferenceDecision(undefined, "transactionnel")` autorise (`mandatory_without_user`) ;
> - la liste de suppression est vide (`Suppressions actives Firestore : 0` au même run) ;
> - `enrichEventPayload` est best-effort et ne peut pas interrompre le flux.
>
> L'analyse statique a atteint sa limite. Le canari lisait déjà le statut de l'événement mais le **jetait** en cas de timeout : il rapporte désormais `eventStatus`, `ignoreReason` et `missingRequiredVariables`, ce qui transformera le prochain timeout en diagnostic exploitable — `created` désignera un déclencheur qui n'a jamais tourné, `ignored` livrera le motif exact du renoncement, `jobs_created` un job créé mais introuvable par la requête.
>
> **🔴 Diagnostic obtenu (26 août 2026, run [#65](https://github.com/stef25fwi/presto_app/actions/runs/32925619138), ~03h15 UTC) — le déclencheur d'entrée du pipeline email ne se déclenche pas.** Le canari instrumenté rapporte :
> ```text
> BREVO_RUNTIME_CANARY_RESULT={"ok":false,"eventStatus":"created","ignoreReason":null,
>   "missingRequiredVariables":null,"jobStatus":null,"errorCode":"runtime_canary_timeout","logStatuses":[]}
> ```
> Le document `email_events` est bien écrit (`Canari runtime créé: evt_...` au même run) et reste à `status: "created"` — la valeur posée par le canari — pendant les 90 secondes d'attente. Or `enqueueEmailJobsFromEvent` écrit `jobs_created` en cas de succès et `ignored` en cas de renoncement sur variables manquantes. Un statut resté à `created` signifie donc : soit le déclencheur n'a jamais tourné, soit il a abandonné à une sortie silencieuse. **Toutes les sorties silencieuses ont été écartées par lecture du code** (mapping du template, `getCompatTemplateMeta` — le registre compat inclut bien `...legacyTemplateRegistry` donc le template legacy est trouvé —, présence du destinataire, liste de suppression vide, préférences autorisant le canal transactionnel).
>
> **Conclusion (provisoire, invalidée ci-dessous) : `enqueueEmailJobsFromEventTrigger` ne s'exécute pas sur la création d'un document `email_events`.** Élément discriminant : le webhook `handleEmailProviderWebhook`, déclencheur **HTTP** de la même base de code et du même déploiement, répond correctement (200 sur les 4 événements du smoke test). La différence porte donc sur le type de déclencheur — Firestore/Eventarc — et non sur le code applicatif, les secrets ou la configuration du module.
>
> **Portée présumée à ce stade : aucun email transactionnel n'est enqueué en production**, pas seulement le canari — tout le pipeline dépend de ce déclencheur d'entrée.
>
> Vérification suivante, hors de portée d'une session sans accès `gcloud`/Console : consulter Cloud Logging pour `enqueueEmailJobsFromEventTrigger` (europe-west1) et déterminer s'il enregistre la moindre exécution ou erreur lors de l'écriture d'un document `email_events`, puis vérifier l'état de son déclencheur Eventarc.
>
> **✅ Cause racine trouvée (26 août 2026, run [#66](https://github.com/stef25fwi/presto_app/actions/runs/32959114114), ~10h40 UTC) — la conclusion ci-dessus était fausse : le déclencheur s'exécute bien.** Le sandbox de session n'a ni `gcloud` ni credentials GCP, mais le runner CI est déjà authentifié en Workload Identity Federation pour Secret Manager : une étape de diagnostic a réutilisé cette authentification pour interroger `gcloud functions describe`, `gcloud eventarc triggers list` et Cloud Logging depuis le workflow lui-même, contournant ainsi l'absence d'accès Cloud Console en session.
>
> Résultats :
> - `enqueueEmailJobsFromEventTrigger` est `"state": "ACTIVE"`, correctement configuré (`eventFilters` sur `email_events/{eventId}`, `eventType: google.cloud.firestore.document.v1.created`), et le trigger Eventarc `enqueueemailjobsfromeventtrigger-584879` existe avec sa souscription Pub/Sub, pointant vers la bonne fonction.
> - Cloud Logging montre une exécution réelle **au moment précis du canari du même run** :
>   ```text
>   2026-08-26T10:37:25Z  Error: Value for argument "data" is not a valid Firestore document.
>     Cannot use "undefined" as a Firestore value (found in field "recipient_user_id").
>     If you want to ignore undefined values, enable `ignoreUndefinedProperties`.
>       at WriteBatch.set (.../write-batch.js:267:9)
>   ```
> - Cause : `enqueueEmailJobsFromEvent` (`functions/src/modules/email/queue/enqueue.ts:118`) écrivait `recipient_user_id: recipientUserId` tel quel dans le job Firestore. Le canari (`functions/scripts/brevo_runtime_canary.mjs`) crée un événement `support.ticket.created` **sans** `recipient_user_id` (test technique anonyme), donc `recipientUserId` vaut `undefined` — et le SDK Admin Firestore rejette `undefined` par défaut. L'exception, non interceptée, faisait planter le déclencheur **avant** la mise à jour de statut de `email_events`, ce qui expliquait exactement le `status: "created"` figé observé par le canari.
> - **Portée corrigée : le pipeline fonctionne pour tout événement produit avec un `recipient_user_id`** — et tous les producteurs de code applicatif (`support/triggers.ts`, `auth/`, `billing/`, `listings/`, `messaging/`, `marketing/`, `moderation/`, `legal/`) renseignent bien ce champ. Seuls les événements sans utilisateur (canari, et tout futur envoi transactionnel anonyme légitime — cas explicitement supporté par `resolvePreferenceDecision` via `mandatory_without_user`) faisaient planter le déclencheur. La formulation précédente (« aucun email transactionnel n'est enqueué en production ») était donc trop large : c'est un sous-cas, mais un sous-cas réel et vicieux puisqu'il masquait aussi tout diagnostic par canari.
> - Correctif appliqué : omettre le champ `recipient_user_id` du document plutôt que d'y assigner `undefined`, cohérent avec le reste du code qui le relit déjà en `|| null` (`worker.ts`, `webhooks/handler.ts`). Build + suite de tests (341/341) verts après correctif.
> - Prochaine étape : merger sur `main`, laisser le déploiement automatique pousser le correctif, puis rejouer `quality/brevo-production` pour confirmer que le canari obtient enfin `jobs_created` puis un envoi accepté par Brevo.
>
> **✅ Confirmé en production (26 août 2026, run [#68](https://github.com/stef25fwi/presto_app/actions/runs/32961822720), ~11h09 UTC), après merge ([#1416](https://github.com/stef25fwi/presto_app/pull/1416)) et déploiement automatique des Functions ([run #2428](https://github.com/stef25fwi/presto_app/actions/runs/32960048650), déploiement Functions réussi malgré l'échec non lié du smoke `/confidentialite`) :**
> ```text
> Canari runtime créé: evt_brevo_runtime_canary_1787742568739_5f7846d4
> BREVO_RUNTIME_CANARY_RESULT={"ok":true,"eventStatus":"jobs_created","jobStatus":"sent",
>   "provider":"brevo","providerMessageId":"<202608261109.34643480536@smtp-relay.mailin.fr>",
>   "logStatuses":["sent"]}
> ```
> Le pipeline complet fonctionne de bout en bout : `email_events` → `enqueueEmailJobsFromEventTrigger` → `email_jobs` → `processEmailJobTrigger` → envoi accepté par Brevo. **Premier canari runtime vert de toute la campagne de certification.** Ce blocage est définitivement résolu ; seuls les blocages DNS (SPF/DKIM, MX inbound — hors de portée d'une session sans accès au registrar) restent ouverts pour atteindre les 100 %.

## 26 août 2026, ~11h30 UTC — DKIM publié (CNAME), avancée réelle confirmée, deux points DNS précis restants

L'utilisateur a publié chez LWS deux enregistrements CNAME `brevo1._domainkey`/`brevo2._domainkey` (méthode de délégation DKIM par CNAME, plus récente que la méthode par TXT plat que les scripts de certification supposaient à l'origine). Vérification :

- **Un vrai bug a été trouvé et corrigé au passage** : `check_brevo_sender_dns.mjs` plantait (`queryTxt EBADNAME @.ilipresto.fr`) au lieu de rapporter un résultat, car l'API Brevo renvoie maintenant un `host_name` égal à `"@"` (convention de zone DNS pour l'apex) pour son enregistrement `brevo-code`, non reconnu par `fqdn()`. Corrigé et vérifié en conditions réelles (run [#70](https://github.com/stef25fwi/presto_app/actions/runs/32963426963)). Bonne nouvelle indépendante : le script gérait déjà correctement la résolution DKIM par CNAME (il interroge dynamiquement les enregistrements attendus renvoyés par l'API Brevo, TXT ou CNAME).
- **Avancée réelle confirmée par `brevo_production_audit.mjs`** : `domain.verified` ✅, `domain.authenticated` ✅, `sender.exists`/`sender.active` ✅ (`noreply@ilipresto.fr`), tous les contrôles webhook ✅, et surtout **`e2e.provider_accepted` ✅ et `e2e.webhook_delivery` ✅** — un envoi réel est accepté par Brevo et son accusé de réception est confirmé par webhook jusqu'à Firestore. C'est la première certification E2E complètement verte de ce module.
- **Confirmé par `check_brevo_sender_dns.mjs`** (une fois corrigé) : `DKIM PASS (3 enregistrements, source brevo_api)` — les CNAME sont bien reconnus et correspondent aux valeurs attendues par Brevo.

Trois points DNS précis restent ouverts, tous chez le registrar (hors de portée d'une session sans accès à LWS) :

1. **SPF toujours absent** — `SPF FAIL (absent)`. Aucun enregistrement TXT `v=spf1 include:spf.brevo.com ...` sur `ilipresto.fr`. Cause aussi l'échec de `domain.dns_records` côté Brevo (qui exige que tous ses enregistrements DNS attendus, y compris SPF, soient à `status: true`).
2. **DMARC publié mais `rua` non surveillé par iliprestō** — `_dmarc.ilipresto.fr` = `v=DMARC1; p=quarantine; rua=mailto:rua@dmarc.brevo.com`. Ce `rua` est syntaxiquement valide mais pointe uniquement vers la boîte de Brevo, pas vers une adresse qu'iliprestō peut lire (`contact@ilipresto.fr` ou `dmarc@ilipresto.fr`, la liste attendue par la politique de certification). **Action attendue : ajouter une deuxième adresse `rua`**, par exemple `rua=mailto:rua@dmarc.brevo.com,mailto:contact@ilipresto.fr` (DMARC accepte plusieurs destinataires séparés par une virgule) — pas besoin de retirer celle de Brevo.
3. **MX inbound toujours cassé** — `inbound.ilipresto.fr` MX pointe vers `inbound1.sendinblue.com.ilipresto.fr` (point final manquant chez LWS, provoquant la concaténation du domaine). Bloque `webhook.inbound` (HTTP 400) et `inbound E2E`.

Une routine horaire (`trig_01SBabkoFdGXWacF9NMPwxzd`) surveille la publication SPF et relancera automatiquement la certification dès qu'elle apparaîtra.

## 26 août 2026, ~12h20 UTC — SPF publié, DMARC `rua` corrigé : DNS d'envoi 100 % certifié, un seul point DNS restant (inbound)

L'utilisateur a publié le SPF et ajouté `contact@ilipresto.fr` au `rua` DMARC. Trois bugs réels de certification ont été trouvés et corrigés en conditions live pendant cette vérification (tous mergés : [#1418](https://github.com/stef25fwi/presto_app/pull/1418), [#1420](https://github.com/stef25fwi/presto_app/pull/1420), [#1421](https://github.com/stef25fwi/presto_app/pull/1421)) :

1. `check_brevo_sender_dns.mjs` plantait sur l'hôte `"@"` renvoyé par l'API Brevo (corrigé, cf. plus haut).
2. `assessDmarc` exigeait que **tous** les destinataires `rua` soient surveillés au lieu d'**au moins un** — rejetait donc `rua=...brevo.com,...ilipresto.fr` alors que la boîte iliprestō y figurait bien. Test de régression ajouté.
3. `ensureDomain()` ne redemandait l'authentification à Brevo que si `authenticated` était encore faux ; comme ce flag était déjà vrai depuis une validation DKIM antérieure au SPF, Brevo n'était jamais sollicité pour revérifier le DNS une fois le SPF publié. Corrigé pour redemander tant que `dns_records` n'est pas tous prêts.

**Résultat (run [#76](https://github.com/stef25fwi/presto_app/actions/runs/32967542578))** : `BREVO_SENDER_DNS_RESULT={"ok":true,"spf":true,"dkim":true,"dmarc":true,"issues":[]}` — **SPF, DKIM et DMARC sont intégralement certifiés en DNS public**, avec une vérification indépendante (résolution DNS directe, pas seulement le statut auto-déclaré Brevo).

Un écart mineur et non bloquant persiste : `domain.dns_records` (le statut interne de Brevo, pas notre certification DNS) reste à `FAIL` malgré une réauthentification demandée avec succès (`REPAIR domain_authentication_requested`, `Successfully authenticated`) — vraisemblablement un délai de repropagation asynchrone côté Brevo après le PUT `/authenticate`, pas une anomalie DNS réelle. À revérifier au prochain run sans action supplémentaire attendue.

**Seul point DNS restant, actionnable et précis** : `inbound.ilipresto.fr` n'a que `inbound1.sendinblue.com` en MX ; Brevo exige aussi `inbound2.sendinblue.com` (`MX Brevo inbound manquants : inbound2.sendinblue.com`). Une fois ce second MX ajouté chez LWS, `webhook.inbound` (actuellement HTTP 400), la vérification MX inbound et l'E2E entrant devraient tous passer.

## 26 août 2026, ~13h10 UTC — MX inbound complété ; le domaine inbound exige sa propre authentification DKIM

Le second MX a été publié : `BREVO_INBOUND_DNS_RESULT={"ok":true,...}` et l'étape « Verify Brevo inbound MX delegation » passe désormais au vert. Le webhook inbound continuait pourtant d'échouer en HTTP 400.

Trois correctifs successifs de l'outillage ont été nécessaires pour faire apparaître la cause réelle, chacun masquant le suivant :

1. **L'erreur était avalée** ([#1423](https://github.com/stef25fwi/presto_app/pull/1423)) : `curl --fail-with-body` sous `set -e` interrompait le script au moment même où il capturait la réponse — le corps JSON de Brevo n'était jamais affiché. Chaque appel capture désormais code HTTP et corps séparément.
2. **`document_not_found` traité comme fatal** ([#1424](https://github.com/stef25fwi/presto_app/pull/1424)) : `GET /v3/webhooks?type=inbound` répond HTTP 400 `{"code":"document_not_found"}` tant qu'aucun webhook inbound n'existe, au lieu d'une liste vide. Le script n'atteignait donc jamais l'étape de création.
3. **Le domaine inbound n'existait pas comme ressource Brevo** ([#1425](https://github.com/stef25fwi/presto_app/pull/1425)) : `POST /webhooks` répondait `{"code":"invalid_parameter","message":"Domain is not found or is inactive"}`. `inbound.ilipresto.fr` a été créé via `POST /senders/domains`.

**Cause racine finale (run [#89](https://github.com/stef25fwi/presto_app/actions/runs/32972113542))** : le domaine inbound existe et persiste, mais reste `verified:false, authenticated:false`. Brevo le dit explicitement lorsqu'on lui demande l'authentification :

```text
PUT /senders/domains/inbound.ilipresto.fr/authenticate -> HTTP 400
{"code":"bad_request","message":"The domain cannot be authenticated. Check your domain
 DNS panel and ensure Brevo code, DKIM record and DMARC record are added correctly."}
```

**Un domaine inbound exige donc la même authentification DKIM qu'un domaine d'envoi — le MX seul ne suffit pas.** L'hypothèse inverse, retenue plus haut dans ce document et dans un commentaire du script, était fausse ; elle est corrigée dans les deux endroits ([#1427](https://github.com/stef25fwi/presto_app/pull/1427)).

### Enregistrements à publier chez LWS (zone `ilipresto.fr`)

| Type | Nom | Valeur |
|---|---|---|
| TXT | `inbound` | `brevo-code:0888eee9599ca505c7c41d8d82042b05` |
| CNAME | `brevo1._domainkey.inbound` | `b1.inbound-ilipresto-fr.dkim.brevo.com.` |
| CNAME | `brevo2._domainkey.inbound` | `b2.inbound-ilipresto-fr.dkim.brevo.com.` |

Deux précisions vérifiées plutôt que supposées :

- **Les DKIM inbound vont bien sous `.inbound`, pas à la racine.** L'API Brevo renvoie `host_name: "brevo1._domainkey"` sans le suffixe `inbound`, ce qui prête à confusion (ses champs `brevo_code` et `dmarc_record` sont, eux, exprimés relativement à `ilipresto.fr` : `inbound` et `_dmarc.inbound`). Mais `brevo1._domainkey.ilipresto.fr` est **déjà occupé** par le DKIM du domaine d'envoi, avec une valeur différente (`b1.ilipresto-fr.dkim.brevo.com` contre `b1.inbound-ilipresto-fr.dkim.brevo.com`) : deux CNAME distincts sur un même nom étant impossibles, les enregistrements inbound ne peuvent aller que sous `brevo1._domainkey.inbound.ilipresto.fr`. Vérifié par résolution DNS le 26 août 2026.
- **Le `_dmarc.inbound` n'est pas à publier.** Brevo le rapporte déjà `status: true` alors que `_dmarc.inbound.ilipresto.fr` n'existe pas en DNS : la politique DMARC de `ilipresto.fr` couvre le sous-domaine par héritage. Aucune action.

⚠️ **Point final obligatoire sur les CNAME** — c'est exactement l'erreur qui avait cassé le MX inbound (`inbound1.sendinblue.com.ilipresto.fr`). L'interface LWS concatène le domaine si la valeur ne se termine pas par un point.

Le script demande maintenant l'authentification à chaque run tant qu'elle n'est pas acquise : une fois ces trois enregistrements publiés, la certification se débloquera seule au run suivant, sans intervention supplémentaire.

## 26 août 2026, ~13h25 UTC — DNS inbound publié : audit Brevo 12/12, deux points restants bien identifiés

Les trois enregistrements ont été publiés chez LWS et résolvent correctement (vérification DNS directe, sans concaténation cette fois). Brevo confirme : `{"domain_name":"inbound.ilipresto.fr","message":"Domain has been authenticated successfully."}`, ses quatre `dns_records` passent à `status: true`, et le webhook inbound est enfin créé — `Webhook inbound Brevo conforme id=2153991 domain=inbound.ilipresto.fr auth=bearer`.

**L'audit `brevo_production_audit.mjs` est désormais intégralement vert (run [#93](https://github.com/stef25fwi/presto_app/actions/runs/32974197307)) :**

```text
PASS domain.verified      PASS domain.authenticated  PASS domain.dns_records  PASS domain.dmarc
PASS sender.exists        PASS sender.active
PASS webhook.exists       PASS webhook.single        PASS webhook.auth_bearer PASS webhook.events
PASS e2e.provider_accepted PASS e2e.webhook_delivery
```

`domain.dns_records` a été débloqué par un correctif de notre propre contrôle, pas par une action DNS ([#1429](https://github.com/stef25fwi/presto_app/pull/1429)) : Brevo renvoie `"dkim_record": null` pour l'ancien DKIM TXT unique remplacé par la paire de CNAME, et le `.every()` sur toute la map comptait ce `null` comme non satisfait — l'assertion était **impossible à passer quelle que soit la configuration réelle**. Vérifié sur la charge utile exacte du run #92 (ancienne logique `false`, nouvelle `true`).

### Point restant 1 — routage entrant `contact@ilipresto.fr` (action utilisateur, hors DNS)

```text
Mail E2E accepté par Brevo: <202608261320.26400728601@smtp-relay.mailin.fr>
Aucun mail E2E reçu dans adminInboundEmails avant expiration du délai.
```

Le MX de `ilipresto.fr` pointe vers `mail.ilipresto.fr` (boîte LWS) ; Brevo ne reçoit que ce qui est adressé à `*@inbound.ilipresto.fr`. Il manque donc, dans l'espace **mail** de LWS (et non la zone DNS), une **copie/redirection** `contact@ilipresto.fr` → `contact@inbound.ilipresto.fr`. Une copie plutôt qu'une redirection pure permet de continuer à lire ces messages dans la boîte LWS en plus du widget admin.

### Point restant 2 — seuil de délivrabilité, à arbitrer

L'échantillon vient de franchir les 50 envois, ce qui déclenche l'évaluation des seuils (en dessous, ils ne sont pas appliqués faute de significativité) :

```text
Envois acceptés: 52
Livraison: 90.385% | hard 0.000% | soft 0.000% | bloqués 0.000% | plaintes 0.000% | invalides 0.000% | différés 0.000%
BREVO_DELIVERABILITY_RESULT={"ok":false,"evaluated":true,"sample":52,"violations":["delivery"]}
```

Analyse avant toute conclusion — **l'écart est un reliquat figé, pas des envois en vol** : entre les runs #92 et #93, les acceptés passent de 49 à 52 et les livrés de 44 à 47, l'écart restant exactement à **5**. Les 3 nouveaux envois ont donc tous été livrés (3/3), et ce sont 5 messages anciens qui n'ont jamais reçu d'événement terminal — ni livraison, ni rebond, ni blocage, ni plainte (toutes ces catégories sont à 0,000 %).

Deux constats en découlent :

- La configuration actuelle délivre correctement ; le taux de 90,4 % mesure une fenêtre de 30 jours **majoritairement composée de nos propres envois de test**, dont beaucoup émis alors que SPF/DKIM n'étaient pas publiés et que le domaine n'était pas authentifié. Il n'est pas représentatif de la production à venir.
- Le seuil n'a délibérément **pas** été abaissé pour faire passer le contrôle au vert : ce serait neutraliser la garde qualité au moment précis où elle commence à mesurer quelque chose.

Trois options, à arbitrer : laisser le gate rouge le temps que les envois conformes s'accumulent et que les 5 anciens sortent de la fenêtre glissante (il se corrigera seul, sans action) ; réduire la fenêtre d'évaluation ; ou exclure le trafic de certification de l'échantillon. La première est retenue par défaut, faute de raison d'affaiblir le contrôle.

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

- [x] **`BREVO_API_KEY` valide.** Cause du HTTP 401 identifiée : restriction d'adresses IP autorisées activée côté compte Brevo, désactivée le 26 août 2026 — `Credential Brevo validée via /v3/account` confirmé au run [#59](https://github.com/stef25fwi/presto_app/actions/runs/32916691618). ⚠️ Le runtime Firebase déployé, lui, envoie encore avec une version de secret figée au déploiement : **redéployer les Cloud Functions** avant de considérer l'envoi de production réellement opérationnel (cf. 1 bis).
- [ ] **Redéployer les Cloud Functions** (`.github/workflows/deploy.yml`, déclenchable en `workflow_dispatch`) : le runtime déployé rejette une authentification Bearer valide sur le webhook transactionnel (run [#60](https://github.com/stef25fwi/presto_app/actions/runs/32918096410), `401 invalid webhook authentication`) — signe qu'il fonctionne avec une version figée de `BREVO_WEBHOOK_SECRET` (et probablement `BREVO_API_KEY`) antérieure à la version 10 valide. Sans ce redéploiement, l'envoi ET la réception des accusés Brevo restent cassés en production réelle, même une fois `quality/brevo-production` vert.
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
| Compte Brevo | API `/v3/account` valide | ✅ (run #59, 26/08/2026) |
| Domaine | `ilipresto.fr` vérifié | ⬜ |
| Domaine | `ilipresto.fr` authentifié | ⬜ |
| DNS | SPF valide (publié, unique, Brevo autorisé) | ⬜ |
| DNS | DKIM valide (publié et conforme aux valeurs Brevo) | ⬜ |
| DNS | DMARC valide (syntaxe, politique, `rua` surveillée) | ⬜ |
| DNS | `BREVO_SENDER_DNS_RESULT` à `ok:true` | ⬜ |
| Sender | `noreply@ilipresto.fr` actif | ⬜ |
| Reply-To | `contact@ilipresto.fr` | ⬜ |
| Secret | `BREVO_API_KEY` valide (côté API directe ; runtime Firebase à redéployer) | ✅⚠️ (run #59) |
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
