# Publier les annonces marketplace approuvées mais bloquées en pending

Ce script publie uniquement les annonces de listings qui sont encore bloquées en pending et prêtes à publication:

- status = pending
- moderationStatus in [approved, auto_flagged, manual_review, vide]
- mediaProcessingStatus in [completed, vide]

Dry run:

node tools/publish_approved_pending_listings.cjs --limit=100

Publication effective:

node tools/publish_approved_pending_listings.cjs --limit=100 --apply

Filtrer sur un propriétaire précis:

OWNER_ID=uid_utilisateur node tools/publish_approved_pending_listings.cjs --limit=100 --apply

Le script force ensuite:

- status = active
- visibility = public
- publishedAt = serverTimestamp()
- autoPublishAfter = null
