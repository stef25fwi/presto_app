# ChatGPT ↔ Brevo MCP — iliprestō

## Objectif

Architecture d’administration cible :

```text
ChatGPT
  │
  │ MCP distant via HTTPS
  │ Authorization: Bearer <BREVO_MCP_TOKEN>
  ▼
Brevo MCP officiel
https://mcp.brevo.com/v1/brevo/mcp
  │
  ▼
Compte Brevo iliprestō
```

Cette intégration utilise le serveur MCP officiel Brevo. Aucun proxy Firebase ou serveur MCP maison n’est requis pour relier ChatGPT à Brevo.

Le pipeline applicatif reste indépendant :

```text
iliprestō / Firebase Functions → API Brevo → destinataires
```

Le MCP est uniquement un canal d’administration :

```text
ChatGPT → MCP Brevo officiel → compte Brevo iliprestō
```

## Endpoint officiel Brevo

Serveur principal :

```text
https://mcp.brevo.com/v1/brevo/mcp
```

Brevo fournit aussi des serveurs spécialisés permettant d’appliquer le principe du moindre privilège :

```text
https://mcp.brevo.com/v1/brevo_contacts/mcp
https://mcp.brevo.com/v1/brevo_campaign_analytics/mcp
https://mcp.brevo.com/v1/brevo_templates/mcp
https://mcp.brevo.com/v1/brevo_transac_templates/mcp
https://mcp.brevo.com/v1/brevo_senders/mcp
https://mcp.brevo.com/v1/brevo_domains/mcp
https://mcp.brevo.com/v1/brevo_webhooks_management/mcp
```

## Token MCP Brevo

Dans Brevo :

1. Ouvrir **Account → SMTP & API → API Keys**.
2. Créer une nouvelle clé en activant l’option **MCP**.
3. Copier le token une seule fois vers le mécanisme sécurisé d’authentification du connecteur.
4. Ne jamais le stocker dans Git, Flutter, Firebase Hosting, un fichier `.env` versionné, un ticket, un log ou une conversation ChatGPT.

Authentification attendue :

```text
Authorization: Bearer <BREVO_MCP_TOKEN>
```

`BREVO_MCP_TOKEN`, `BREVO_API_KEY` et `BREVO_WEBHOOK_SECRET` sont trois secrets distincts. Aucun ne doit être exposé dans le client Flutter.

## État de compatibilité ChatGPT — 23 août 2026

La prise en charge complète des apps MCP personnalisées dans ChatGPT, incluant les actions de modification/écriture, est disponible en bêta pour les offres **Business, Enterprise et Edu** sur ChatGPT web.

Une offre **ChatGPT Plus** ne permet pas actuellement d’importer cette app MCP personnalisée. Aucun plugin Brevo n’est actuellement disponible dans le répertoire ChatGPT pour contourner proprement cette limitation.

Conséquence : la partie serveur/repository peut être préparée et certifiée, mais l’activation effective `ChatGPT → MCP Brevo` nécessite un espace ChatGPT Business/Enterprise/Edu ou une évolution ultérieure de la disponibilité produit.

## Configuration ChatGPT quand le plan est compatible

Depuis ChatGPT web :

1. Activer le mode développeur dans les paramètres de l’espace de travail.
2. Ouvrir **Paramètres → Apps → Créer**.
3. Nom recommandé : `Brevo iliprestō`.
4. URL MCP : `https://mcp.brevo.com/v1/brevo/mcp`.
5. Configurer l’authentification Bearer avec le token MCP Brevo.
6. Analyser les outils exposés par le serveur.
7. Vérifier la liste des outils avant publication.
8. Conserver une confirmation explicite pour les actions d’écriture sensibles.

## Politique de moindre privilège recommandée

Phase 1 — lecture/audit uniquement :

- senders ;
- domaines ;
- statistiques de campagnes ;
- templates transactionnels ;
- état des webhooks ;
- événements transactionnels et délivrabilité.

Phase 2 — écritures faibles risques :

- correction contrôlée d’un template de test ;
- création d’un contact de test ;
- ajout d’une note ou d’une ressource non destructive.

Phase 3 — actions sensibles, uniquement avec confirmation explicite :

- envoi de campagne ;
- import/export massif ;
- suppression de contacts ;
- modification de domaines, senders, webhooks ou permissions ;
- opérations SMS/WhatsApp.

## Tests de validation iliprestō

Après connexion, exécuter d’abord des demandes en lecture seule :

```text
Vérifie les senders et domaines Brevo du compte iliprestō et signale toute configuration non validée. Ne modifie rien.
```

```text
Analyse les événements transactionnels des dernières 24 heures : sent, delivered, deferred, soft bounce, hard bounce, blocked, complaint et error. Ne modifie rien.
```

```text
Liste les templates transactionnels et signale ceux dont l’expéditeur ou le reply-to n’est pas cohérent avec ilipresto.fr. Ne modifie rien.
```

```text
Vérifie les webhooks transactionnels Brevo et signale tout endpoint manquant ou désactivé. Ne modifie rien.
```

Une seule action d’écriture à faible risque doit être testée ensuite. Ne jamais commencer par un envoi massif.

## Sécurité et exploitation

- Ne jamais committer `BREVO_MCP_TOKEN`.
- Révoquer immédiatement un token supposé exposé.
- Utiliser un token MCP distinct du token API applicatif.
- Préférer les endpoints spécialisés lorsque le serveur principal expose plus d’outils que nécessaire.
- Conserver les confirmations ChatGPT pour les écritures sensibles.
- Ne jamais utiliser le MCP comme remplacement du pipeline transactionnel Firebase.
- Auditer régulièrement senders, domaines, templates, webhooks, bounces, blocks et complaints.

## Critères de validation

- [x] Architecture MCP officielle Brevo documentée.
- [x] Endpoint officiel Brevo documenté.
- [x] Séparation `BREVO_MCP_TOKEN` / `BREVO_API_KEY` / `BREVO_WEBHOOK_SECRET` documentée.
- [x] Règles de moindre privilège documentées.
- [x] Procédure de tests de lecture et d’écriture contrôlée documentée.
- [x] Aucun secret MCP stocké dans le dépôt.
- [ ] Token MCP Brevo créé dans le compte Brevo.
- [ ] App `Brevo iliprestō` créée dans ChatGPT web.
- [ ] Analyse des outils MCP réussie.
- [ ] Audit senders/domaines/templates/webhooks réussi depuis ChatGPT.
- [ ] Une action d’écriture faible risque testée avec confirmation explicite.

Les cinq derniers contrôles nécessitent un espace ChatGPT compatible et/ou une action dans le compte Brevo ; ils ne peuvent pas être automatisés depuis le dépôt GitHub.