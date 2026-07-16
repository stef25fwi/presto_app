import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { buildPublicationGate } from './check_parcours_publication_gate.mjs';

const rulesPath = 'quality/parcours_fiches_audit_rules.json';

function fiche(overrides = {}) {
  return {
    id_fiche: 'fiche_test',
    titre: 'Fiche test',
    statut_utilisateur: 'fonctionnaire',
    categorie: 'Services',
    activite: 'Test',
    famille: 'Services généraux',
    type_activite: 'Prestation de services',
    activite_reglementee: false,
    niveau_vigilance: 'faible',
    statut_recommande: 'micro-entrepreneur',
    organisme_formalite: 'Guichet unique INPI',
    sources_officielles: ['https://entreprendre.service-public.fr/'],
    version: '2026-07-16',
    legal_review_status: 'vérifié',
    review_status: 'validee',
    reviewed_at: '2026-07-16',
    next_review_at: '2027-01-16',
    reviewer: 'équipe contenu',
    parcours: {
      '4_demarches': [
        "Vérifier le droit d'exercer",
        'Sécuriser la situation personnelle',
        "Définir l'offre et le budget",
        'Vérifier les aides',
        'Choisir le statut',
        'Préparer le dossier',
        "Déclarer l'activité",
        'Souscrire les assurances',
        'Organiser la gestion',
        'Lancer la première prestation'
      ]
    },
    ...overrides,
  };
}

function fixture({ ficheValue, published }) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'parcours-publish-'));
  const jsonDir = path.join(root, 'catalogue', 'json');
  fs.mkdirSync(jsonDir, { recursive: true });
  fs.writeFileSync(path.join(jsonDir, 'fiche.json'), JSON.stringify(ficheValue));
  const manifest = path.join(root, 'manifest.json');
  fs.writeFileSync(manifest, JSON.stringify({ published }));
  return { root, manifest };
}

test('une fiche validée, propre et planifiée est autorisée', () => {
  const data = fixture({ ficheValue: fiche(), published: ['fiche_test'] });
  const report = buildPublicationGate({ root: data.root, manifestPath: data.manifest, rulesPath, today: '2026-07-16' });
  assert.equal(report.allowed, 1);
  assert.equal(report.rejected, 0);
});

test('une fiche corrigée mais non validée est refusée', () => {
  const data = fixture({ ficheValue: fiche({ review_status: 'corrigee' }), published: ['fiche_test'] });
  const report = buildPublicationGate({ root: data.root, manifestPath: data.manifest, rulesPath, today: '2026-07-16' });
  assert.equal(report.allowed, 0);
  assert.match(report.results[0].reasons.join(' '), /statut/i);
});

test('une date de révision échue bloque une fiche publiée', () => {
  const data = fixture({ ficheValue: fiche({ review_status: 'publiee', next_review_at: '2026-01-01' }), published: ['fiche_test'] });
  const report = buildPublicationGate({ root: data.root, manifestPath: data.manifest, rulesPath, today: '2026-07-16' });
  assert.equal(report.allowed, 0);
  assert.match(report.results[0].reasons.join(' '), /calendrier/i);
});

test('une fiche absente du catalogue est refusée', () => {
  const data = fixture({ ficheValue: fiche(), published: ['inconnue'] });
  const report = buildPublicationGate({ root: data.root, manifestPath: data.manifest, rulesPath, today: '2026-07-16' });
  assert.equal(report.allowed, 0);
  assert.match(report.results[0].reasons.join(' '), /introuvable/i);
});

test('un manifeste vide passe pendant la migration historique', () => {
  const data = fixture({ ficheValue: fiche(), published: [] });
  const report = buildPublicationGate({ root: data.root, manifestPath: data.manifest, rulesPath, today: '2026-07-16' });
  assert.equal(report.allAllowed, true);
  assert.equal(report.requested, 0);
});
