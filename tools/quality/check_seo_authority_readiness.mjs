import assert from 'node:assert/strict';
import fs from 'node:fs';

const registry = JSON.parse(fs.readFileSync('quality/seo-authority-targets.json', 'utf8'));
const page = fs.readFileSync('web/presse.html', 'utf8');
const firebase = JSON.parse(fs.readFileSync('firebase.json', 'utf8'));

assert.equal(registry.version, 1, 'Version du registre autorité inattendue');
assert.equal(registry.policy.paidLinksAllowed, false, 'Les liens payants doivent rester interdits');
assert.equal(registry.policy.reciprocalLinkSchemesAllowed, false, 'Les schémas de liens réciproques doivent rester interdits');
assert.equal(registry.policy.massDirectorySubmissionAllowed, false, 'La soumission massive aux annuaires doit rester interdite');
assert.ok(Array.isArray(registry.targets) && registry.targets.length >= 5, 'Portefeuille de cibles trop faible');

const allowedStatuses = new Set(['candidate', 'contacted', 'earned', 'declined', 'not-eligible']);
const ids = new Set();
for (const target of registry.targets) {
  assert.match(String(target.id || ''), /^[a-z0-9-]+$/, 'ID cible invalide');
  assert.ok(!ids.has(target.id), `Cible dupliquée: ${target.id}`);
  ids.add(target.id);
  assert.ok(String(target.name || '').trim().length >= 3, `${target.id}: nom absent`);
  assert.ok(String(target.territory || '').trim().length >= 3, `${target.id}: territoire absent`);
  assert.ok(String(target.type || '').trim().length >= 3, `${target.id}: type absent`);
  assert.ok(String(target.url || '').startsWith('https://'), `${target.id}: URL HTTPS requise`);
  assert.ok(allowedStatuses.has(target.status), `${target.id}: statut invalide`);
  assert.ok(String(target.routeToEarn || '').trim().length >= 40, `${target.id}: stratégie d'obtention trop vague`);
  assert.equal(target.landingPage, '/presse', `${target.id}: landing page d'autorité incorrecte`);
}

assert.ok(page.includes('<link rel="canonical" href="https://ilipresto.fr/presse">'), 'Canonical presse absente');
assert.ok(page.includes('0 % de commission'), 'Positionnement 0 % absent de la page presse');
assert.ok(page.includes('n’achète pas de liens'), 'Politique anti-liens artificiels absente');
assert.ok(page.includes('/services/'), 'Lien vers hub services absent');
assert.ok(page.includes('/missions/'), 'Lien vers hub missions absent');

for (const target of ['production', 'mirror']) {
  const hosting = firebase.hosting.find((entry) => entry.target === target);
  assert.ok(hosting, `Hosting target ${target} absent`);
  assert.ok((hosting.rewrites || []).some((r) => r.source === '/presse' && r.destination === '/presse.html'), `${target}: rewrite /presse absent`);
  assert.ok((hosting.redirects || []).some((r) => r.source === '/presse/' && r.destination === '/presse' && r.type === 301), `${target}: redirect /presse/ absent`);
  assert.ok((hosting.redirects || []).some((r) => r.source === '/presse.html' && r.destination === '/presse' && r.type === 301), `${target}: redirect /presse.html absent`);
}

console.log(`SEO autorité: ${registry.targets.length} cibles qualifiées, page presse et politique anti-liens artificiels validées.`);
