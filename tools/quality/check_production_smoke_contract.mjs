import fs from 'node:fs';

const workflowPath = '.github/workflows/deploy.yml';
const workflow = fs.readFileSync(workflowPath, 'utf8');

const startMarker = '      - name: Production smoke tests';
const endMarker = '      - name: Publish deployment summary';
const start = workflow.indexOf(startMarker);
const end = workflow.indexOf(endMarker, start + startMarker.length);

if (start < 0 || end < 0 || end <= start) {
  console.error('❌ Impossible de localiser le bloc Production smoke tests dans deploy.yml.');
  process.exit(1);
}

const smoke = workflow.slice(start, end);
const failures = [];

function requireText(text, label) {
  if (!smoke.includes(text)) {
    failures.push(`élément requis absent: ${label}`);
  }
}

function forbid(regex, label) {
  if (regex.test(smoke)) {
    failures.push(`motif interdit détecté: ${label}`);
  }
}

requireText('set -euo pipefail', 'mode Bash strict');
requireText('assert_contains()', 'helper assert_contains');
requireText('assert_not_contains()', 'helper assert_not_contains');
requireText('BASH_REMATCH[0]', 'extraction d’URL sans pipeline grep|head');
requireText('https://ilipresto.fr/confidentialite', 'smoke confidentialité');
requireText('https://ilipresto.fr/suppression-compte', 'smoke suppression de compte');
requireText('test "$missing_listing_status" = "404"', 'contrôle 404 annonce absente');
requireText("assert_not_contains \"$local_page\" 'JobPosting'", 'absence JobPosting page locale');
requireText("assert_not_contains \"$listing_page\" 'JobPosting'", 'absence JobPosting annonce publique');

// Avec `set -o pipefail`, `producer | grep -q` peut échouer après un match valide
// lorsque grep ferme le pipe tôt (SIGPIPE côté producteur). Les assertions sur du
// contenu déjà chargé en mémoire doivent donc rester sans pipeline.
forbid(/echo\s+"\$[A-Za-z_][A-Za-z0-9_]*"\s*\|\s*grep\s+-[^\n]*q/m, 'echo "$variable" | grep -q sous pipefail');
forbid(/printf\s+[^\n]*\|\s*grep\s+-[^\n]*q/m, 'printf ... | grep -q sous pipefail');
forbid(/\|\s*head\s+-n\s*1/m, 'pipeline vers head -n 1 dans le smoke production');

if (failures.length > 0) {
  console.error('❌ Contrat du smoke production invalide:');
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}

console.log('✅ Contrat du smoke production valide: assertions sans faux négatif pipefail.');
