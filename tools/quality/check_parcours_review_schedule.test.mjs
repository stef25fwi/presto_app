import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { buildReviewSchedule, reviewState } from './check_parcours_review_schedule.mjs';

test('une fiche validée sans prochaine révision est bloquante', () => {
  const result = reviewState({ review_status: 'validee' }, '2026-07-16');
  assert.equal(result.state, 'unscheduled');
  assert.equal(result.blocking, true);
});

test('une fiche corrigée sans calendrier reste visible mais non bloquante', () => {
  const result = reviewState({ review_status: 'corrigee' }, '2026-07-16');
  assert.equal(result.state, 'unscheduled');
  assert.equal(result.blocking, false);
});

test('une révision future est planifiée', () => {
  const result = reviewState({ review_status: 'validee', reviewed_at: '2026-07-16', next_review_at: '2027-01-16' }, '2026-07-16');
  assert.equal(result.state, 'scheduled');
  assert.equal(result.blocking, false);
});

test('une fiche publiée dont la date est dépassée devient bloquante', () => {
  const result = reviewState({ review_status: 'publiee', next_review_at: '2026-01-01' }, '2026-07-16');
  assert.equal(result.state, 'overdue');
  assert.equal(result.blocking, true);
});

test('le rapport inventorie les calendriers du catalogue', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'parcours-review-'));
  const jsonDir = path.join(root, 'pack', 'json');
  fs.mkdirSync(jsonDir, { recursive: true });
  fs.writeFileSync(path.join(jsonDir, 'a.json'), JSON.stringify({ id_fiche: 'a', activite: 'A', review_status: 'validee', next_review_at: '2027-01-01' }));
  fs.writeFileSync(path.join(jsonDir, 'b.json'), JSON.stringify({ id_fiche: 'b', activite: 'B', review_status: 'publiee', next_review_at: '2026-01-01' }));
  const report = buildReviewSchedule({ roots: [root], today: '2026-07-16' });
  assert.equal(report.totalFiles, 2);
  assert.equal(report.blockingFiles, 1);
  assert.equal(report.byState.scheduled, 1);
  assert.equal(report.byState.overdue, 1);
});
