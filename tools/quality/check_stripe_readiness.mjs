import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const configPath = path.join(root, 'quality', 'stripe-readiness.json');
const enforce = process.argv.includes('--enforce');

if (!fs.existsSync(configPath)) {
  console.error('Configuration Stripe absente.');
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
if (config.schemaVersion !== 1 || config.phase !== 11 || !Array.isArray(config.controls)) {
  console.error('Configuration Stripe invalide.');
  process.exit(1);
}

const allowed = new Set(['implemented', 'pending', 'not_applicable']);
const failures = [];
const controls = config.controls.map((control) => {
  const evidence = Array.isArray(control.evidence) ? control.evidence : [];
  const evidenceExists = evidence.every((entry) => fs.existsSync(path.join(root, entry)));
  if (!control.id || !allowed.has(control.status)) failures.push(`Contrôle invalide: ${control.id ?? 'sans-id'}`);
  if (control.status === 'implemented' && !evidence.length) failures.push(`${control.id}: preuve absente`);
  if (control.status === 'implemented' && !evidenceExists) failures.push(`${control.id}: chemin de preuve introuvable`);
  if (enforce && control.required && control.status !== 'implemented') failures.push(`${control.id}: contrôle requis non implémenté`);
  return {...control, evidenceExists};
});

const report = {
  generatedAt: new Date().toISOString(),
  phase: 11,
  enforce,
  passed: failures.length === 0,
  summary: {
    total: controls.length,
    implemented: controls.filter((item) => item.status === 'implemented').length,
    pending: controls.filter((item) => item.status === 'pending').length
  },
  controls,
  failures
};

const reportDir = path.join(root, 'quality_reports', 'stripe-readiness');
fs.mkdirSync(reportDir, {recursive: true});
fs.writeFileSync(path.join(reportDir, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report.summary));
if (failures.length) {
  console.error(failures.join('\n'));
  process.exit(1);
}
