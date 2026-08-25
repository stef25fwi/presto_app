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

---

# 5. Expéditeur et Reply-To

Configuration cible :

```text
From: iliprestō <noreply@ilipresto.fr>
Reply-To: contact@ilipresto.fr
```

- [ ] `noreply@ilipresto.fr` existe dans Brevo.
- [ ] Le sender est actif.
- [ ] Le sender utilise le domaine authentifié `ilipresto.fr`.
- [ ] Aucun sender de test ne reste sélectionné en production.
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

- [ ] Définir des seuils internes d’alerte pour bounce et complaint.
- [ ] Définir le comportement lorsqu’un seuil est dépassé.
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
- [ ] Empêcher les boucles d’envoi vers une adresse déjà supprimée.
- [ ] Vérifier les règles RGPD applicables aux données conservées dans les logs/suppressions.

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

- [ ] Valider `BREVO_API_KEY`.
- [ ] Valider `BREVO_WEBHOOK_SECRET`.
- [ ] Finaliser SPF/DKIM/DMARC.
- [ ] Authentifier `ilipresto.fr`.
- [ ] Activer `noreply@ilipresto.fr`.
- [ ] Certifier le webhook transactionnel.
- [ ] Réussir l’E2E sortant.
- [ ] Finaliser `inbound.ilipresto.fr`.
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
| DNS | SPF valide | ⬜ |
| DNS | DKIM valide | ⬜ |
| DNS | DMARC valide | ⬜ |
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
