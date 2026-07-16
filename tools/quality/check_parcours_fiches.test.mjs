import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { auditDirectory, auditFiche, normalizeText } from './check_parcours_fiches.mjs';

const rules = JSON.parse(fs.readFileSync('quality/parcours_fiches_audit_rules.json', 'utf8'));

function validFiche(overrides = {}) {
  return {
    id_fiche: 'fonctionnaire_test',
    titre: 'Test — fonctionnaire',
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
    legal_review_status: 'socle vérifié',
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
        'Souscrire les assurances et préparer les factures',
        'Organiser la gestion',
        'Lancer la première prestation'
      ]
    },
    ...overrides,
  };
}

test('normalizeText rapproche casse, accents et ponctuation', () => {
  assert.equal(normalizeText('  Déclaration — SAP ! '), 'declaration sap');
});

test('une fiche déménagement contaminée par SAP est bloquée', () => {
  const result = auditFiche(validFiche({
    activite: 'Aide déménagement',
    famille: 'Aide à domicile / Services à la personne',
    qualification_regles: 'Déclaration via Nova SAP et intervention auprès de publics fragiles.'
  }), rules);
  assert.ok(result.issues.some((entry) => entry.code === 'demenagement-ne-doit-pas-etre-sap' && entry.severity === 'blocker'));
  assert.equal(result.validForPublication, false);
});

test('une fiche validée sans erreur bloquante est publiable', () => {
  const result = auditFiche(validFiche(), rules);
  assert.equal(result.counts.blocker ?? 0, 0);
  assert.equal(result.counts.error ?? 0, 0);
  assert.equal(result.validForPublication, true);
});

test('les doublons de coûts sont signalés', () => {
  const result = auditFiche(validFiche({
    couts_indicatifs: ['RC pro : devis à demander', 'RC pro : devis à demander']
  }), rules);
  assert.ok(result.issues.some((entry) => entry.code === 'duplicate-within-collection'));
});

test('auditDirectory produit un inventaire et détecte les identifiants en double', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'parcours-audit-'));
  const jsonDir = path.join(root, 'pack', 'json');
  fs.mkdirSync(jsonDir, { recursive: true });
  fs.writeFileSync(path.join(jsonDir, 'a.json'), JSON.stringify(validFiche()));
  fs.writeFileSync(path.join(jsonDir, 'b.json'), JSON.stringify(validFiche({ titre: 'Autre fiche' })));
  const report = auditDirectory({ roots: [root], rulesPath: 'quality/parcours_fiches_audit_rules.json' });
  assert.equal(report.inventory.totalFiles, 2);
  assert.ok(report.fiches.some((fiche) => fiche.issues.some((entry) => entry.code === 'duplicate-id')));
});
