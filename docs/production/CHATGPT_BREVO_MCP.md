# ChatGPT ↔ Brevo MCP — iliprestō

## Architecture cible

```text
ChatGPT
  │
  │ MCP over HTTPS
  │ Authorization: Bearer <BREVO_MCP_TOKEN>
  ▼
Brevo MCP officiel
https://mcp.brevo.com/v1/brevo/mcp
  │
  ▼
API / compte Brevo iliprestō
```

Cette intégration utilise le serveur MCP officiel Brevo. Aucun proxy Firebase ou serveur MCP maison n'est nécessaire pour la connexion ChatGPT ↔ Brevo.

## Sécurité

- Ne jamais stocker `BREVO_MCP_TOKEN` dans Git, dans Flutter, dans Firebase Hosting ou dans un fichier versionné.
- Le token MCP doit être généré depuis Brevo : **Account → SMTP & API → API Keys → créer une clé en cochant MCP**.
- L'authentification du serveur MCP Brevo utilise l'en-tête HTTP :

```text
Authorization: Bearer <BREVO_MCP_TOKEN>
```

- Ne jamais réutiliser `BREVO_API_KEY` comme valeur documentée ou committée pour le connecteur ChatGPT.
- Révoquer immédiatement le token MCP en cas de doute sur une fuite.
- Les actions d'envoi, de modification de contacts, de campagnes, de templates, de domaines, de senders ou de webhooks doivent rester soumises à confirmation côté ChatGPT lorsque cette option est proposée.

## Endpoint principal Brevo

```text
https://mcp.brevo.com/v1/brevo/mcp
```

Le serveur principal expose l'ensemble des modules Brevo. Pour réduire les droits fonctionnels, Brevo fournit aussi des endpoints MCP spécialisés, notamment :

```text
https://mcp.brevo.com/v1/brevo_campaign_analytics/mcp
https://mcp.brevo.com/v1/brevo_transac_templates/mcp
https://mcp.brevo.com/v1/brevo_senders/mcp
https://mcp.brevo.com/v1/brevo_domains/mcp
https://mcp.brevo.com/v1/brevo_webhooks_management/mcp
https://mcp.brevo.com/v1/brevo_contacts/mcp
```

Pour une première connexion de production iliprestō, privilégier le serveur principal uniquement si les contrôles d'actions ChatGPT sont disponibles. Sinon, créer plusieurs apps MCP spécialisées afin d'appliquer le principe du moindre privilège.

## Configuration ChatGPT

### Prérequis OpenAI

Au 11 août 2026, les apps MCP personnalisées et le mode développeur ChatGPT sont disponibles sur ChatGPT **Business et Enterprise/Edu**, sur le web. Une offre ChatGPT Plus seule ne permet pas d'activer directement cette app MCP personnalisée.

### Création de l'app

Depuis ChatGPT web, avec un compte éligible :

1. Activer le **mode développeur** dans les paramètres Apps de l'espace de travail.
2. Ouvrir **Paramètres → Apps → Créer**.
3. Nom recommandé : `Brevo iliprestō`.
4. Endpoint :

   ```text
   https://mcp.brevo.com/v1/brevo/mcp
   ```

5. Configurer l'authentification Bearer avec le `BREVO_MCP_TOKEN` généré dans Brevo.
6. Lancer **Analyser les outils**.
7. Vérifier la liste des outils détectés avant de créer/publier l'app.
8. Pour les actions d'écriture, conserver les confirmations utilisateur et limiter les actions publiées quand le plan ChatGPT le permet.

## Tests de réception / production iliprestō

Après connexion, exécuter ces requêtes dans une conversation ChatGPT avec l'app `Brevo iliprestō` activée :

```text
Vérifie les senders et domaines Brevo du compte iliprestō et signale toute configuration non validée.
```

```text
Analyse les événements transactionnels des dernières 24 heures : sent, delivered, deferred, soft bounce, hard bounce, blocked, complaint et error. Ne modifie rien.
```

```text
Liste les templates transactionnels et signale ceux dont l'expéditeur ou le reply-to n'est pas cohérent avec ilipresto.fr. Ne modifie rien.
```

```text
Vérifie les webhooks transactionnels Brevo et signale tout endpoint manquant ou désactivé. Ne modifie rien.
```

## Test d'écriture contrôlé

Une fois les audits en lecture validés, tester une seule action d'écriture à faible risque et confirmer explicitement l'action dans ChatGPT. Ne jamais commencer par une campagne ou un envoi massif.

## Relation avec l'infrastructure Firebase existante

Le pipeline email de l'application reste :

```text
iliprestō / Firebase Functions → API Brevo → destinataires
```

Le MCP ChatGPT est un canal d'administration distinct :

```text
ChatGPT → MCP Brevo officiel → compte Brevo iliprestō
```

Il ne remplace ni `BREVO_API_KEY`, ni `BREVO_WEBHOOK_SECRET`, ni les fonctions Firebase de production. Il permet à ChatGPT d'auditer et, selon les autorisations du compte, d'administrer Brevo sans donner le secret Brevo au code client.

## Critères de validation

- [ ] Token MCP Brevo créé et stocké uniquement dans le mécanisme de secret/authentification du connecteur.
- [ ] Aucun token MCP dans le dépôt GitHub.
- [ ] App `Brevo iliprestō` créée dans ChatGPT web sur un plan compatible.
- [ ] Analyse des outils MCP réussie.
- [ ] Audit senders/domaines réussi.
- [ ] Audit événements transactionnels réussi.
- [ ] Audit templates réussi.
- [ ] Audit webhooks réussi.
- [ ] Une action d'écriture faible risque testée avec confirmation explicite.
- [ ] Token révoqué/rotaté si un secret a été copié dans un endroit non prévu.
