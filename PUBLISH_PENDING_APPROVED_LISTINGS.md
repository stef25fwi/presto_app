# Publier les annonces marketplace approuvées mais bloquées en pending

Ce script publie uniquement les annonces de `listings` qui ont déjà été approuvées mais qui sont encore bloquées avec:

- `status = pending`
- `moderationStatus = approved`
- `mediaProcessingStatus = completed`

Dry run:

```bash
node tools/publish_approved_pending_listings.cjs
```

Publication effective:

```bash
node tools/publish_approved_pending_listings.cjs --apply
```

Filtrer sur un propriétaire précis:

```bash
OWNER_ID=uid_utilisateur node tools/publish_approved_pending_listings.cjs --apply
```

Le script force ensuite:

- `status = active`
- `visibility = public`
- `publishedAt = serverTimestamp()`
- `autoPublishAfter = null`
