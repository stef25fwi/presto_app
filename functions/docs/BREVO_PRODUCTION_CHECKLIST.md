# Brevo Production Checklist

## 1) Secrets et variables

- `BREVO_API_KEY` present in Firebase Functions secrets.
- `BREVO_WEBHOOK_SECRET` present in Firebase Functions secrets.
- `EMAIL_PROVIDER_NAME` set to `brevo` in production (explicit mode recommended).
- `EMAIL_FROM` configured with a validated Brevo sender domain or sender identity.
- If no authenticated domain exists yet in Brevo, keep `EMAIL_FROM` on the validated sender identity until DNS auth is completed.

Verification commands:

```bash
firebase functions:secrets:get BREVO_API_KEY --project presto-app-74abe
firebase functions:secrets:get BREVO_WEBHOOK_SECRET --project presto-app-74abe
```

## 2) Déploiement

- Build passes in `functions`.
- Tests pass in `functions`.
- Deploy only functions after verification.

```bash
cd functions
npm run build
npm run test
cd ..
firebase deploy --only functions --project presto-app-74abe
```

## 3) Vérification webhook

- Run the smoke test with valid webhook URL and secret.
- Confirm all requests return HTTP 200.

```bash
cd functions
node scripts/brevo_webhook_smoke_test.mjs \
  --url "https://<region>-<project>.cloudfunctions.net/handleEmailProviderWebhook" \
  --secret "<BREVO_WEBHOOK_SECRET>"
```

## 4) Post-deploy observability

- Check `email_provider_webhooks` documents for `signature_valid=true`.
- Check `email_logs` records for delivered/opened/clicked test events.
- Confirm no unexpected growth in `email_suppressions`.

## 5) Safety gates before go-live

- No provider factory fallback ambiguity in production config.
- At least one real transactional email sent and tracked end-to-end.
- Alerting in place for webhook signature failure spikes.

## 6) ChatGPT ↔ Brevo MCP

- Use the official Brevo MCP endpoint rather than introducing a custom Firebase proxy solely for ChatGPT administration.
- Generate a dedicated Brevo MCP token; never commit it or expose it to Flutter/web clients.
- Follow `docs/production/CHATGPT_BREVO_MCP.md` for endpoint, security controls, ChatGPT prerequisites and validation tests.
- Validate read-only audits first (senders/domains, transactional events, templates, webhooks).
- Test write access only after the read path is validated, starting with one low-risk action requiring explicit confirmation.
- Keep the production application path `Firebase Functions → Brevo API` separate from the administration path `ChatGPT → Brevo MCP`.
