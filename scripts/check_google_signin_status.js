#!/usr/bin/env node

/**
 * Vérification visuelle de la configuration Google Sign-In
 * Usage: node check_google_signin_status.js
 */

const fs = require('fs');
const path = require('path');

console.clear();
console.log('🔍 DIAGNOSTIC GOOGLE SIGN-IN - 6 janvier 2026');
console.log('═══════════════════════════════════════════════════\n');

const checks = [];

// 1. Vérifier web/index.html
console.log('1️⃣  Vérification web/index.html...');
try {
  const htmlPath = path.join(__dirname, 'web', 'index.html');
  const htmlContent = fs.readFileSync(htmlPath, 'utf8');
  
  const hasClientId = htmlContent.includes('google-signin-client_id');
  const hasBadClientId = htmlContent.includes('xxxxxxxxxx');
  
  if (hasClientId && !hasBadClientId) {
    const match = htmlContent.match(/content="(151421230024-[^"]+)"/);
    if (match) {
      console.log(`   ✅ Client ID trouvé: ${match[1].substring(0, 40)}...`);
      checks.push(true);
    } else {
      console.log('   ⚠️  Client ID format invalide');
      checks.push(false);
    }
  } else if (hasBadClientId) {
    console.log('   ❌ Client ID avec xxxxxxxxxx (à corriger)');
    checks.push(false);
  } else {
    console.log('   ❌ Client ID non trouvé');
    checks.push(false);
  }
} catch (e) {
  console.log(`   ❌ Erreur: ${e.message}`);
  checks.push(false);
}
console.log('');

// 2. Vérifier firebase_options.dart
console.log('2️⃣  Vérification lib/firebase_options.dart...');
try {
  const firebasePath = path.join(__dirname, 'lib', 'firebase_options.dart');
  const firebaseContent = fs.readFileSync(firebasePath, 'utf8');
  
  const hasProjectId = firebaseContent.includes('projectId: \'presto-app-74abe\'');
  const hasApiKey = firebaseContent.includes('apiKey:');
  const hasAuthDomain = firebaseContent.includes('authDomain:');
  
  if (hasProjectId && hasApiKey && hasAuthDomain) {
    console.log('   ✅ Configuration Firebase correcte');
    console.log('      - Project ID: presto-app-74abe');
    console.log('      - API Key: présent');
    console.log('      - Auth Domain: présent');
    checks.push(true);
  } else {
    console.log('   ❌ Configuration Firebase incomplète');
    checks.push(false);
  }
} catch (e) {
  console.log(`   ❌ Erreur: ${e.message}`);
  checks.push(false);
}
console.log('');

// 3. Vérifier lib/main.dart
console.log('3️⃣  Vérification lib/main.dart...');
try {
  const mainPath = path.join(__dirname, 'lib', 'main.dart');
  const mainContent = fs.readFileSync(mainPath, 'utf8');
  
  const hasSignInMethod = mainContent.includes('Future<void> _signInWithGoogle()');
  const hasGoogleAuthService = mainContent.includes('GoogleAuthService');
  const hasSignInWithGoogle = mainContent.includes('_signInWithGoogle');
  
  let methodCount = (mainContent.match(/_signInWithGoogle/g) || []).length;
  
  if (hasSignInMethod && hasGoogleAuthService && hasSignInWithGoogle) {
    console.log('   ✅ Méthode _signInWithGoogle() implémentée');
    console.log(`      - Utilisations: ${methodCount}`);
    console.log('      - GoogleAuthService: intégré');
    checks.push(true);
  } else {
    console.log('   ❌ Implémentation incomplète');
    checks.push(false);
  }
} catch (e) {
  console.log(`   ❌ Erreur: ${e.message}`);
  checks.push(false);
}
console.log('');

// 4. Vérifier GoogleAuthService
console.log('4️⃣  Vérification lib/services/google_auth_service.dart...');
try {
  const servicePath = path.join(__dirname, 'lib', 'services', 'google_auth_service.dart');
  const serviceContent = fs.readFileSync(servicePath, 'utf8');
  
  const hasGetErrorMessage = serviceContent.includes('getErrorMessage');
  const hasLogAttempt = serviceContent.includes('logAttempt');
  const hasShouldFallback = serviceContent.includes('shouldFallbackToRedirect');
  
  if (hasGetErrorMessage && hasLogAttempt && hasShouldFallback) {
    console.log('   ✅ GoogleAuthService complet');
    console.log('      - Messages d\'erreur: présents');
    console.log('      - Logging: implémenté');
    console.log('      - Fallback popup→redirect: présent');
    checks.push(true);
  } else {
    console.log('   ⚠️  GoogleAuthService partiellement complet');
    checks.push(false);
  }
} catch (e) {
  console.log(`   ❌ Erreur: ${e.message}`);
  checks.push(false);
}
console.log('');

// 5. Vérifier pubspec.yaml
console.log('5️⃣  Vérification pubspec.yaml...');
try {
  const pubspecPath = path.join(__dirname, 'pubspec.yaml');
  const pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
  
  const hasFirebaseAuth = pubspecContent.includes('firebase_auth');
  const hasGoogleSignIn = pubspecContent.includes('google_sign_in');
  const hasFirebaseCore = pubspecContent.includes('firebase_core');
  
  if (hasFirebaseAuth && hasGoogleSignIn && hasFirebaseCore) {
    console.log('   ✅ Dépendances correctes');
    console.log('      - firebase_auth: ✅');
    console.log('      - google_sign_in: ✅');
    console.log('      - firebase_core: ✅');
    checks.push(true);
  } else {
    console.log('   ❌ Dépendances manquantes');
    checks.push(false);
  }
} catch (e) {
  console.log(`   ❌ Erreur: ${e.message}`);
  checks.push(false);
}
console.log('');

// 6. Vérifier le bouton UI
console.log('6️⃣  Vérification bouton UI...');
try {
  const mainPath = path.join(__dirname, 'lib', 'main.dart');
  const mainContent = fs.readFileSync(mainPath, 'utf8');
  
  const hasButton = mainContent.includes('Continuer avec Google');
  const hasOnPressed = mainContent.includes('onPressed: _isLoading ? null : _signInWithGoogle');
  
  if (hasButton && hasOnPressed) {
    console.log('   ✅ Bouton UI correctement câblé');
    console.log('      - Label: "Continuer avec Google"');
    console.log('      - Handler: _signInWithGoogle');
    checks.push(true);
  } else {
    console.log('   ❌ Bouton non correctement configuré');
    checks.push(false);
  }
} catch (e) {
  console.log(`   ❌ Erreur: ${e.message}`);
  checks.push(false);
}
console.log('');

// 7. Résumé
console.log('═══════════════════════════════════════════════════');
console.log('📊 RÉSUMÉ\n');

const passed = checks.filter(c => c).length;
const total = checks.length;
const percentage = Math.round((passed / total) * 100);

console.log(`Checks réussis: ${passed}/${total} (${percentage}%)\n`);

if (passed === total) {
  console.log('🎉 ✅ TOUT EST CONFIGURÉ!');
  console.log('');
  console.log('Prochaines étapes:');
  console.log('  1. flutter clean');
  console.log('  2. flutter build web');
  console.log('  3. flutter run -d chrome');
  console.log('  4. Tester "Se connecter avec Google"');
  console.log('');
  console.log('Configuration Firebase Console à vérifier:');
  console.log('  - Google Sign-In: activé');
  console.log('  - Authorized domains: localhost + stef25fwi.github.io + presto-app-74abe.web.app');
  console.log('  - OAuth consent screen: configuré');
  console.log('');
} else if (passed >= total - 1) {
  console.log('⚠️  Presque prêt! Quelques ajustements...');
  console.log('');
  const failedChecks = checks.map((c, i) => ({ index: i + 1, passed: c }))
    .filter(c => !c.passed);
  
  failedChecks.forEach(c => {
    console.log(`  ❌ Check ${c.index} échoué`);
  });
  console.log('');
} else {
  console.log('❌ Configuration incomplète');
  console.log('   Consulter GOOGLE_SIGNIN_DEBUG.md pour les détails');
  console.log('');
}

console.log('═══════════════════════════════════════════════════');
