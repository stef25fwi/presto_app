export const communicationPreferencesExample = {
  locale: "fr",
  timezone: "Europe/Paris",
  transactionalEmailEnabled: true,
  lifecycleEmailEnabled: true,
  marketingEmailEnabled: false,
  messageEmailEnabled: true,
  nearbyListingsEnabled: true,
  referralEnabled: true,
  unsubscribeToken: "usr_unsub_token_xxx",
};

export const emailLogExample = {
  eventType: "billing.payment.succeeded",
  templateId: "payment_confirmed",
  templateCode: "tpl_transactional_payment_confirmed_v2",
  userId: "user_123",
  recipient: "client@example.com",
  status: "sent",
  provider: "resend",
  providerMessageId: "re_123",
  createdAt: Date.now(),
  sentAt: Date.now(),
  locale: "fr",
  category: "billing",
  type: "transactional",
  retryCount: 0,
  metadata: {
    invoiceId: "inv_123",
  },
};

export const emailEventExample = {
  event_id: "evt_payment_succeeded_inv_123",
  event_name: "billing.payment.succeeded",
  source_collection: "billing_invoices",
  source_id: "inv_123",
  recipient_user_id: "user_123",
  dedupe_key: "sha256:billing.payment.succeeded:inv_123",
  occurred_at: Date.now(),
  payload: {
    recipient_email: "client@example.com",
    firstName: "Nadia",
    amount: 29.99,
    invoiceUrl: "https://presto.app/facturation",
  },
  status: "created",
};