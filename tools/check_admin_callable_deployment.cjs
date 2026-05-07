/**
 * Vérifie si getMyAdminAccessStatus est joignable en europe-west1.
 * Utilise une requête HTTP sans auth : une réponse 401/unauthenticated
 * confirme que la fonction est déployée. Un timeout ou 404 indique un
 * problème de déploiement ou de région.
 *
 * Usage : node tools/check_admin_callable_deployment.cjs
 */

'use strict';

const https = require('https');

const PROJECT_ID = 'presto-app-74abe';
const REGION = 'europe-west1';
const FUNCTION_NAME = 'getMyAdminAccessStatus';

const URL = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;

console.log(`\n[check-admin-callable] Vérification déploiement`);
console.log(`  Fonction : ${FUNCTION_NAME}`);
console.log(`  Région   : ${REGION}`);
console.log(`  URL      : ${URL}\n`);

const body = JSON.stringify({ data: {} });

const options = {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body),
  },
};

const req = https.request(URL, options, (res) => {
  let raw = '';
  res.on('data', (chunk) => { raw += chunk; });
  res.on('end', () => {
    const status = res.statusCode;
    let parsed = null;
    try { parsed = JSON.parse(raw); } catch (_) {}

    console.log(`  HTTP status : ${status}`);
    if (parsed) {
      console.log(`  Réponse     :`, JSON.stringify(parsed, null, 2));
    } else {
      console.log(`  Réponse raw :`, raw.slice(0, 300));
    }

    console.log('');
    if (status === 401 || (parsed && (parsed.error?.status === 'UNAUTHENTICATED' || parsed.error?.message?.includes('unauthenticated')))) {
      console.log('✅ RÉSULTAT : Fonction DÉPLOYÉE en', REGION);
      console.log('   (elle répond unauthenticated, ce qui est attendu sans token)');
    } else if (status === 200) {
      console.log('✅ RÉSULTAT : Fonction DÉPLOYÉE et accessible (réponse 200)');
    } else if (status === 404) {
      console.log('❌ RÉSULTAT : Fonction INTROUVABLE en', REGION, '(404)');
      console.log('   → Lancer "Admin Callable: Build + Deploy getMyAdminAccessStatus"');
    } else if (status === 403) {
      console.log('⚠️  RÉSULTAT : Fonction DÉPLOYÉE mais App Check actif (403 forbidden)');
      console.log('   → La fonction est présente, mais App Check bloque les appels non munis d\'un token');
    } else {
      console.log(`⚠️  RÉSULTAT : Réponse inattendue HTTP ${status}`);
      console.log('   → Vérifier les logs Firebase pour plus de détails');
    }
    console.log('');
  });
});

req.on('error', (err) => {
  console.error('❌ Connexion échouée :', err.message);
  if (err.code === 'ENOTFOUND') {
    console.error('   → Résolution DNS impossible. Vérifie ta connexion.');
  } else if (err.code === 'ECONNREFUSED') {
    console.error('   → Connexion refusée. La fonction n\'est peut-être pas déployée.');
  }
  process.exit(1);
});

req.setTimeout(10000, () => {
  console.error('❌ Timeout (10s). La fonction ne répond pas.');
  console.error('   → Fonction non déployée ou région incorrecte.');
  req.destroy();
  process.exit(1);
});

req.write(body);
req.end();
