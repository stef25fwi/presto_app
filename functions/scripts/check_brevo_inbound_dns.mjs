#!/usr/bin/env node
import { resolveMx } from 'node:dns/promises';

const domain = process.env.INBOUND_DOMAIN || 'inbound.ilipresto.fr';
const expected = new Set([
  'inbound1.sendinblue.com',
  'inbound2.sendinblue.com',
]);

const records = await resolveMx(domain);
const normalized = records.map(({ exchange, priority }) => ({
  exchange: String(exchange || '').replace(/\.$/, '').toLowerCase(),
  priority: Number(priority),
}));

const found = new Set(normalized.map((record) => record.exchange));
const missing = [...expected].filter((exchange) => !found.has(exchange));

console.log(`MX ${domain}:`);
for (const record of normalized.sort((a, b) => a.priority - b.priority)) {
  console.log(`- ${record.priority} ${record.exchange}`);
}

if (missing.length > 0) {
  console.error(`MX Brevo inbound manquants pour ${domain}: ${missing.join(', ')}`);
  console.error('Configurer chez LWS les deux MX Brevo inbound avant de relancer la certification.');
  process.exit(2);
}

console.log(`BREVO_INBOUND_DNS_RESULT=${JSON.stringify({ ok: true, domain, records: normalized })}`);
