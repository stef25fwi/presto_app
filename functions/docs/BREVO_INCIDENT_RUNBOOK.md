# Brevo Incident Runbook

## Scope

This runbook covers Brevo email incidents for Firebase Functions pipeline:
- Send failures
- Webhook signature failures
- Bounce/complaint spikes
- Throughput or latency degradation

## 1) Triage in 10 minutes

- Confirm active provider expected in prod (`EMAIL_PROVIDER_NAME=brevo`).
- Inspect recent function logs for:
  - provider_api_key_missing
  - invalid signature
  - network_error
  - http_4xx / http_5xx
- Inspect Firestore collections:
  - `email_provider_webhooks`
  - `email_logs`
  - `email_suppressions`

## 2) Common incidents and actions

### A) Webhook signature suddenly invalid

Symptoms:
- `handleEmailProviderWebhook` returns 401.
- `signature_valid=false` in `email_provider_webhooks`.

Actions:
- Verify Brevo webhook secret in dashboard and Firebase secret match exactly.
- Rotate `BREVO_WEBHOOK_SECRET` if mismatch suspected.
- Re-run smoke test script.

### B) Send errors (4xx/5xx)

Symptoms:
- `email_job_retry_scheduled` increases.
- Error codes like `http_401`, `http_429`, `http_5xx`.

Actions:
- 401/403: rotate `BREVO_API_KEY`, verify sender identity/domain.
- 429: throttle campaigns and retry windows, monitor backlog.
- 5xx/network: keep retries, monitor dead letters, escalate to Brevo status.

### C) Bounce or complaint spike

Symptoms:
- Rapid increase in `email_suppressions`.
- Drop in delivered ratio.

Actions:
- Pause non-essential product/marketing streams.
- Validate recent list source and segmentation rules.
- Check if a bad campaign/template change was deployed.
- Export affected recipients and start remediation.

### D) High queue latency

Symptoms:
- `email_jobs` scheduled/queued age rises.

Actions:
- Check function concurrency and runtime errors.
- Check provider response times and retry rates.
- Temporarily prioritize transactional channels.

## 3) Recovery checklist

- Incident cause identified and documented.
- Secrets rotated if needed.
- Smoke tests green.
- Live transactional test delivered and tracked.
- Backlog processing returns to normal.
- Postmortem created with prevention actions.

## 4) Escalation

Escalate immediately when:
- Transactional delivery disruption > 15 minutes.
- Bounce/complaint rate crosses internal threshold.
- Signature failure persists after secret validation.
