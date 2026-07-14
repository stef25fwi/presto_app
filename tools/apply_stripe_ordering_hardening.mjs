#!/usr/bin/env node

import fs from 'node:fs/promises';

const path = 'functions/src/modules/billing/stripe_webhook.ts';
let content = await fs.readFile(path, 'utf8');

function replaceOnce(before, after, label) {
  if (content.includes(after)) return;
  const count = content.split(before).length - 1;
  const webhookAlreadyHardened =
    content.includes('export function shouldApplyStripeEvent(') &&
    content.includes('last_stripe_event_created_at') &&
    content.includes('normalizedInvoiceStatus(');
  if (count === 0 && webhookAlreadyHardened) {
    return;
  }
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  content = content.replace(before, after);
}

replaceOnce(
  'async function syncSubscription(subscription: JsonMap, eventId: string): Promise<void> {',
  'export function shouldApplyStripeEvent(\n  lastEventCreatedAt: number,\n  incomingEventCreatedAt: number,\n): boolean {\n  return incomingEventCreatedAt <= 0 || lastEventCreatedAt <= incomingEventCreatedAt;\n}\n\nexport function normalizedInvoiceStatus(eventType: string, invoice: JsonMap): string {\n  if (eventType === "invoice.payment_failed") return "payment_failed";\n  if (eventType === "invoice.payment_succeeded" || eventType === "invoice.paid") {\n    return "paid";\n  }\n  return asString(invoice.status || (invoice.paid === true ? "paid" : "open"));\n}\n\nasync function syncSubscription(\n  subscription: JsonMap,\n  eventId: string,\n  eventCreatedAtMs: number,\n): Promise<void> {',
  'stripe ordering helpers and subscription signature',
);

replaceOnce(
  '    latest_invoice_id: asString(subscription.latest_invoice),\n    last_stripe_event_id: eventId,\n    stripe_updated_at: FieldValue.serverTimestamp(),',
  '    latest_invoice_id: asString(subscription.latest_invoice),\n    last_stripe_event_id: eventId,\n    last_stripe_event_created_at: eventCreatedAtMs,\n    stripe_updated_at: FieldValue.serverTimestamp(),',
  'subscription event ordering field',
);

replaceOnce(
  '    stripeUpdatedAt: FieldValue.serverTimestamp(),\n    lastStripeEventId: eventId,\n  };',
  '    stripeUpdatedAt: FieldValue.serverTimestamp(),\n    lastStripeEventId: eventId,\n    lastStripeEventCreatedAt: eventCreatedAtMs,\n  };',
  'user event ordering field',
);

replaceOnce(
  '  const batch = db.batch();\n  batch.set(db.collection(COLLECTIONS.subscriptions).doc(subscriptionId), subscriptionData, { merge: true });\n  batch.set(db.collection(COLLECTIONS.users).doc(userId), userData, { merge: true });\n  await batch.commit();',
  '  const subscriptionRef =\n    db.collection(COLLECTIONS.subscriptions).doc(subscriptionId);\n  const userRef = db.collection(COLLECTIONS.users).doc(userId);\n\n  await db.runTransaction(async (transaction) => {\n    const existing = await transaction.get(subscriptionRef);\n    const lastEventCreatedAt = asNumber(\n      existing.data()?.last_stripe_event_created_at,\n    );\n    if (!shouldApplyStripeEvent(lastEventCreatedAt, eventCreatedAtMs)) {\n      return;\n    }\n\n    transaction.set(subscriptionRef, subscriptionData, { merge: true });\n    transaction.set(userRef, userData, { merge: true });\n  });',
  'transactional subscription ordering',
);

replaceOnce(
  'async function syncInvoice(invoice: JsonMap, eventId: string): Promise<void> {',
  'async function syncInvoice(\n  invoice: JsonMap,\n  eventId: string,\n  eventType: string,\n  eventCreatedAtMs: number,\n): Promise<void> {',
  'invoice signature',
);

replaceOnce(
  '  const status = asString(invoice.status || (invoice.paid === true ? "paid" : "open"));',
  '  const status = normalizedInvoiceStatus(eventType, invoice);',
  'invoice failed status',
);

replaceOnce(
  '    period_end: unixMs(invoice.period_end),\n    last_stripe_event_id: eventId,\n    stripe_updated_at: FieldValue.serverTimestamp(),\n  };\n  await db.collection(COLLECTIONS.billingInvoices).doc(invoiceId).set(data, { merge: true });',
  '    period_end: unixMs(invoice.period_end),\n    last_stripe_event_id: eventId,\n    last_stripe_event_created_at: eventCreatedAtMs,\n    stripe_updated_at: FieldValue.serverTimestamp(),\n  };\n\n  const invoiceRef = db.collection(COLLECTIONS.billingInvoices).doc(invoiceId);\n  await db.runTransaction(async (transaction) => {\n    const existing = await transaction.get(invoiceRef);\n    const lastEventCreatedAt = asNumber(\n      existing.data()?.last_stripe_event_created_at,\n    );\n    if (!shouldApplyStripeEvent(lastEventCreatedAt, eventCreatedAtMs)) {\n      return;\n    }\n    transaction.set(invoiceRef, data, { merge: true });\n  });',
  'transactional invoice ordering',
);

replaceOnce(
  '    await syncSubscription(subscription, eventId);',
  '    await syncSubscription(subscription, eventId, eventCreatedAtMs);',
  'invoice subscription sync ordering',
);

replaceOnce(
  'async function processEvent(event: StripeEvent): Promise<void> {\n  const object = asMap(event.data?.object);',
  'async function processEvent(event: StripeEvent): Promise<void> {\n  const object = asMap(event.data?.object);\n  const eventCreatedAtMs = asNumber(event.created) * 1000;',
  'event timestamp',
);

content = content.replaceAll(
  'await syncSubscription(subscription, event.id);',
  'await syncSubscription(subscription, event.id, eventCreatedAtMs);',
);
content = content.replaceAll(
  'await syncSubscription(object, event.id);',
  'await syncSubscription(object, event.id, eventCreatedAtMs);',
);
replaceOnce(
  '      await syncInvoice(object, event.id);',
  '      await syncInvoice(object, event.id, event.type, eventCreatedAtMs);',
  'invoice event arguments',
);

await fs.writeFile(path, content, 'utf8');
console.log('stripe ordering hardening: OK');

const widgetsPath = 'lib/features/subscriptions/subscription_widgets.dart';
const widgetsBasePath =
  'lib/features/subscriptions/subscription_widgets_base.dart';
let widgetsWrapper = null;
try {
  try {
    widgetsWrapper = await fs.readFile(widgetsPath, 'utf8');
    const widgetsBase = await fs.readFile(widgetsBasePath, 'utf8');
    await fs.writeFile(widgetsPath, widgetsBase, 'utf8');
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
    widgetsWrapper = null;
  }

  try {
    await import('./apply_stripe_checkout_latency_optimization.mjs');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!message.startsWith('audit export:')) throw error;
    console.log('stripe checkout latency core applied; finalizing current index shape');
  }
} finally {
  if (widgetsWrapper != null) {
    await fs.writeFile(widgetsPath, widgetsWrapper, 'utf8');
  }
}

await import('./finalize_stripe_checkout_latency_optimization.mjs');
