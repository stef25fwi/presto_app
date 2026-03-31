#!/usr/bin/env node
// ============================================================================
// Vérification pas à pas : auto-publication d'une annonce marketplace
//
// Usage :
//   node tools/verify_listing_autopublish.cjs [--listing-id=<ID>] [--wait]
//
// --listing-id=xxx : vérifie un listing existant
// --wait           : attend ~70 secondes puis revérifie automatiquement
//
// Sans --listing-id, le script cherche la dernière annonce pending/approved.
// ============================================================================

const admin = require('firebase-admin');

const PROJECT_ID = 'presto-app-74abe';
const WAIT_FLAG = process.argv.includes('--wait');
const LISTING_ID_ARG = process.argv.find((a) => a.startsWith('--listing-id='));
const LISTING_ID = LISTING_ID_ARG ? LISTING_ID_ARG.split('=')[1].trim() : '';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

function norm(val) {
  return String(val ?? '').trim();
}

function tsToISO(ts) {
  if (!ts) return null;
  if (typeof ts.toDate === 'function') return ts.toDate().toISOString();
  if (ts._seconds != null) return new Date(ts._seconds * 1000).toISOString();
  return String(ts);
}

function printSection(title) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`  ${title}`);
  console.log('='.repeat(60));
}

function printField(label, value, expected, ok) {
  const icon = ok ? '✅' : '❌';
  const suffix = expected != null ? ` (attendu: ${expected})` : '';
  console.log(`  ${icon} ${label}: ${JSON.stringify(value)}${suffix}`);
}

// ---------------------------------------------------------------------------
// Étape 1 : Trouver ou charger le document listing
// ---------------------------------------------------------------------------
async function findListing() {
  if (LISTING_ID) {
    const doc = await db.collection('listings').doc(LISTING_ID).get();
    if (!doc.exists) {
      console.error(`❌ Listing ${LISTING_ID} introuvable.`);
      process.exit(1);
    }
    return doc;
  }

  // Chercher les annonces pending/approved (sans orderBy pour éviter un index composite)
  const snap = await db.collection('listings')
    .where('status', '==', 'pending')
    .where('moderationStatus', '==', 'approved')
    .limit(50)
    .get();

  if (!snap.empty) {
    // Trier côté client pour prendre la plus récente
    const sorted = snap.docs.sort((a, b) => {
      const ta = a.data().createdAt?.toMillis?.() ?? 0;
      const tb = b.data().createdAt?.toMillis?.() ?? 0;
      return tb - ta;
    });
    console.log(`📌 Annonce pending/approved trouvée : ${sorted[0].id} (parmi ${snap.size})`);
    return sorted[0];
  }

  // Sinon, chercher la dernière annonce active
  const snapAll = await db.collection('listings')
    .where('status', '==', 'active')
    .limit(10)
    .get();

  if (snapAll.empty) {
    console.error('❌ Aucune annonce trouvée dans la collection listings.');
    process.exit(1);
  }

  const sortedAll = snapAll.docs.sort((a, b) => {
    const ta = a.data().createdAt?.toMillis?.() ?? 0;
    const tb = b.data().createdAt?.toMillis?.() ?? 0;
    return tb - ta;
  });
  console.log(`📌 Dernière annonce active trouvée : ${sortedAll[0].id}`);
  return sortedAll[0];
}

// ---------------------------------------------------------------------------
// Étape 2 : Vérification initiale (juste après soumission)
// ---------------------------------------------------------------------------
function verifyInitialState(data, docId) {
  printSection(`ÉTAPE 2 – Vérification initiale du listing ${docId}`);

  const status = norm(data.status);
  const moderationStatus = norm(data.moderationStatus);
  const visibility = norm(data.visibility);
  const mediaProcessingStatus = norm(data.mediaProcessingStatus);
  const autoPublishAfter = data.autoPublishAfter;

  printField('status', status, 'pending', status === 'pending');
  printField('moderationStatus', moderationStatus, 'approved', moderationStatus === 'approved');
  printField('visibility', visibility, 'private', visibility === 'private');
  printField('mediaProcessingStatus', mediaProcessingStatus, 'completed', mediaProcessingStatus === 'completed');

  if (autoPublishAfter) {
    const apISO = tsToISO(autoPublishAfter);
    const apMs = autoPublishAfter.toMillis ? autoPublishAfter.toMillis() : autoPublishAfter._seconds * 1000;
    const createdMs = data.createdAt?.toMillis ? data.createdAt.toMillis() : (data.createdAt?._seconds ?? 0) * 1000;
    const deltaSec = Math.round((apMs - createdMs) / 1000);
    printField('autoPublishAfter', apISO, '~60s après soumission', deltaSec >= 55 && deltaSec <= 120);
    console.log(`  ℹ️  Délai calculé : ${deltaSec} secondes après createdAt`);
  } else {
    printField('autoPublishAfter', null, 'timestamp présent', false);
  }

  const allOk = status === 'pending' &&
    moderationStatus === 'approved' &&
    visibility === 'private' &&
    mediaProcessingStatus === 'completed' &&
    autoPublishAfter != null;

  console.log(`\n  ${allOk ? '✅ État initial conforme – en attente du scheduler.' : '⚠️  État initial NON conforme.'}`);

  if (!allOk) {
    printSection('DIAGNOSTIC – Pourquoi le document ne basculera pas');
    if (mediaProcessingStatus !== 'completed') {
      console.log('  → mediaProcessingStatus n\'est pas "completed". Les photos sont encore en traitement.');
    }
    if (moderationStatus !== 'approved') {
      console.log('  → moderationStatus n\'est pas "approved". Vérifier le résultat de modération.');
    }
    if (status !== 'pending') {
      console.log(`  → status est "${status}" au lieu de "pending".`);
    }
    if (!autoPublishAfter) {
      console.log('  → autoPublishAfter est absent. autoApprove peut être désactivé ou aucun media.');
    }
  }

  return allOk;
}

// ---------------------------------------------------------------------------
// Étape 4 : Vérification après scheduler (~1 minute)
// ---------------------------------------------------------------------------
function verifyPublishedState(data, docId) {
  printSection(`ÉTAPE 4 – Vérification après scheduler du listing ${docId}`);

  const status = norm(data.status);
  const visibility = norm(data.visibility);
  const publishedAt = data.publishedAt;
  const autoPublishAfter = data.autoPublishAfter;

  printField('status', status, 'active', status === 'active');
  printField('visibility', visibility, 'public', visibility === 'public');
  printField('publishedAt', tsToISO(publishedAt), 'timestamp renseigné', publishedAt != null);
  printField('autoPublishAfter', autoPublishAfter, 'null', autoPublishAfter == null);

  const allOk = status === 'active' &&
    visibility === 'public' &&
    publishedAt != null &&
    autoPublishAfter == null;

  console.log(`\n  ${allOk ? '✅ Publication automatique confirmée !' : '⚠️  Le listing n\'a PAS basculé vers active/public.'}`);

  if (!allOk && status === 'pending') {
    printSection('DIAGNOSTIC – Le scheduler n\'a pas encore publié');
    const apMs = data.autoPublishAfter?.toMillis?.() ?? (data.autoPublishAfter?._seconds ?? 0) * 1000;
    const nowMs = Date.now();
    if (apMs > nowMs) {
      console.log(`  → autoPublishAfter est encore dans le futur (dans ${Math.round((apMs - nowMs) / 1000)}s).`);
    }
    if (norm(data.mediaProcessingStatus) !== 'completed') {
      console.log(`  → mediaProcessingStatus = "${norm(data.mediaProcessingStatus)}" (doit être "completed").`);
    }
    if (norm(data.moderationStatus) !== 'approved') {
      console.log(`  → moderationStatus = "${norm(data.moderationStatus)}" (doit être "approved").`);
    }
    console.log('  → Vérifier les logs Functions pour : marketplace_publish_approved_listings_done');
    console.log('  → Si absent, chercher : marketplace_publish_approved_listings_noop');
  }

  return allOk;
}

// ---------------------------------------------------------------------------
// Étape 8 : Vérification des photos
// ---------------------------------------------------------------------------
function verifyPhotos(data, docId) {
  printSection(`ÉTAPE 8 – Vérification des photos du listing ${docId}`);

  const media = data.media;
  const thumbnailUrl = norm(data.thumbnailUrl);

  if (!Array.isArray(media) || media.length === 0) {
    console.log('  ❌ Aucune photo dans le champ "media".');
    return false;
  }

  console.log(`  📷 ${media.length} photo(s) trouvée(s)`);

  let allPhotosOk = true;
  for (let i = 0; i < media.length; i++) {
    const m = media[i];
    const sp = norm(m.storagePath);
    const dl = norm(m.downloadUrl);
    const th = norm(m.thumbnailUrl);
    const mime = norm(m.mimeType);
    const w = m.width ?? 0;
    const h = m.height ?? 0;

    const hasPath = sp.length > 0;
    const hasUrl = dl.length > 0;
    const isWebp = sp.endsWith('.webp') || mime === 'image/webp';
    const hasDimensions = w > 0 && h > 0;

    console.log(`\n  Photo ${i + 1}:`);
    printField('storagePath', sp.slice(0, 80) + (sp.length > 80 ? '…' : ''), 'non vide', hasPath);
    printField('downloadUrl', dl ? dl.slice(0, 60) + '…' : '', 'non vide', hasUrl);
    printField('thumbnailUrl', th ? th.slice(0, 60) + '…' : '', 'non vide (optionnel)', th.length > 0);
    printField('mimeType', mime, 'image/webp', isWebp);
    printField('dimensions', `${w}x${h}`, '>0', hasDimensions);

    if (!hasPath || !hasUrl) allPhotosOk = false;
  }

  if (thumbnailUrl) {
    console.log(`\n  ✅ thumbnailUrl du listing : ${thumbnailUrl.slice(0, 60)}…`);
  } else {
    console.log('\n  ⚠️  thumbnailUrl du listing est vide.');
    allPhotosOk = false;
  }

  // Vérifier l'accès aux URLs (HEAD request)
  console.log('\n  🔗 Test d\'accès aux URLs des photos…');
  const https = require('https');
  const http = require('http');

  const checkUrl = (url) => new Promise((resolve) => {
    if (!url) { resolve({ ok: false, status: 0 }); return; }
    const mod = url.startsWith('https') ? https : http;
    const req = mod.request(url, { method: 'HEAD', timeout: 8000 }, (res) => {
      resolve({ ok: res.statusCode >= 200 && res.statusCode < 400, status: res.statusCode });
    });
    req.on('error', () => resolve({ ok: false, status: 0 }));
    req.on('timeout', () => { req.destroy(); resolve({ ok: false, status: 0 }); });
    req.end();
  });

  return Promise.all(media.map(async (m, i) => {
    const url = norm(m.downloadUrl);
    if (!url) return;
    const result = await checkUrl(url);
    printField(`Photo ${i + 1} accessible`, result.status, '2xx/3xx', result.ok);
    if (!result.ok) allPhotosOk = false;
  })).then(() => {
    console.log(`\n  ${allPhotosOk ? '✅ Toutes les photos sont bien publiées.' : '⚠️  Certaines photos ont un problème.'}`);
    return allPhotosOk;
  });
}

// ---------------------------------------------------------------------------
// Résumé final
// ---------------------------------------------------------------------------
function printSummary(results) {
  printSection('RÉSUMÉ FINAL');
  for (const [label, ok] of Object.entries(results)) {
    console.log(`  ${ok ? '✅' : '❌'} ${label}`);
  }
  const allOk = Object.values(results).every(Boolean);
  console.log(`\n  ${allOk ? '🎉 Tout est conforme !' : '⚠️  Des problèmes ont été détectés. Voir ci-dessus.'}`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  printSection('ÉTAPE 1 – Recherche du listing');
  const doc = await findListing();
  const docId = doc.id;
  const data = doc.data();

  console.log(`  📄 Listing : ${docId}`);
  console.log(`  📝 Titre   : ${norm(data.title)}`);
  console.log(`  👤 Owner   : ${norm(data.ownerId)}`);
  console.log(`  📅 Créé    : ${tsToISO(data.createdAt)}`);

  const results = {};

  // Le statut actuel détermine quelle vérification faire
  const currentStatus = norm(data.status);

  if (currentStatus === 'pending') {
    // Vérification initiale
    results['État initial (pending/approved)'] = verifyInitialState(data, docId);
    results['Photos'] = await verifyPhotos(data, docId);

    if (WAIT_FLAG) {
      // Calculer le temps d'attente
      const apMs = data.autoPublishAfter?.toMillis?.() ?? 0;
      const nowMs = Date.now();
      const waitMs = Math.max(0, apMs - nowMs) + 15_000; // +15s de marge

      printSection('ÉTAPE 3 – Attente du scheduler');
      console.log(`  ⏳ Attente de ${Math.ceil(waitMs / 1000)} secondes…`);

      await new Promise((resolve) => setTimeout(resolve, waitMs));

      // Recharger le document
      const doc2 = await db.collection('listings').doc(docId).get();
      const data2 = doc2.data();
      results['Publication automatique'] = verifyPublishedState(data2, docId);
      results['Photos après publication'] = await verifyPhotos(data2, docId);
    } else {
      console.log('\n  ℹ️  Relance avec --wait pour attendre automatiquement la bascule.');
      console.log(`  ℹ️  Ou recharge manuellement dans ~1 min avec :`);
      console.log(`     node tools/verify_listing_autopublish.cjs --listing-id=${docId}`);
    }
  } else if (currentStatus === 'active') {
    console.log('  ℹ️  Le listing est déjà actif – vérification post-publication.');
    results['État publié'] = verifyPublishedState(data, docId);
    results['Photos'] = await verifyPhotos(data, docId);
  } else {
    console.log(`  ⚠️  Statut actuel inattendu : "${currentStatus}"`);
    results['Photos'] = await verifyPhotos(data, docId);
  }

  printSummary(results);
}

main().catch((err) => {
  console.error('Erreur fatale :', err);
  process.exitCode = 1;
});
