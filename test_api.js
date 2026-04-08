#!/usr/bin/env node

/**
 * Script de test des clés API Firebase
 * Usage: node test_api.js
 */

const FIREBASE_WEB_API_KEY = process.env.FIREBASE_WEB_API_KEY || '';

if (!FIREBASE_WEB_API_KEY) {
  console.error('Variable d\'environnement requise manquante: FIREBASE_WEB_API_KEY');
  process.exit(1);
}

// Configuration Firebase
const CONFIG = {
  apiKey: FIREBASE_WEB_API_KEY,
  projectId: 'presto-app-74abe',
  authDomain: 'presto-app-74abe.firebaseapp.com',
  storageBucket: 'presto-app-74abe.firebasestorage.app',
};

console.log('🔍 Test des clés API Firebase - Presto App');
console.log('==========================================\n');
console.log('📋 Configuration:');
console.log(`   Project ID: ${CONFIG.projectId}`);
console.log(`   API Key: ${CONFIG.apiKey.substring(0, 20)}...`);
console.log(`   Auth Domain: ${CONFIG.authDomain}\n`);

// Helper pour faire des requêtes HTTP (compatible Node 18+)
async function httpRequest(url, options = {}) {
  try {
    const response = await fetch(url, {
      method: options.method || 'GET',
      headers: options.headers || {},
      body: options.body
    });
    
    const body = await response.text();
    
    return {
      statusCode: response.status,
      body: body,
      headers: response.headers
    };
  } catch (error) {
    throw new Error(`Request failed: ${error.message}`);
  }
}

// Test 1: Firebase Auth API
async function testAuthAPI() {
  console.log('1️⃣  Test Firebase Auth API...');
  try {
    const url = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${CONFIG.apiKey}`;
    const response = await httpRequest(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ returnSecureToken: true })
    });

    if (response.statusCode === 400) {
      const body = JSON.parse(response.body);
      if (body.error && body.error.message === 'MISSING_EMAIL') {
        console.log('   ✅ Firebase Auth API: OK');
        console.log('   (Code 400 attendu sans email - API key valide)\n');
        return true;
      }
    } else if (response.statusCode === 403) {
      console.log('   ❌ API Key invalide ou restrictions IP');
      console.log(`   Response: ${response.body}\n`);
      return false;
    }
    
    console.log(`   ⚠️  HTTP ${response.statusCode}`);
    console.log(`   Response: ${response.body.substring(0, 200)}\n`);
    return false;
  } catch (error) {
    console.log(`   ❌ Erreur: ${error.message}\n`);
    return false;
  }
}

// Test 2: Firestore API
async function testFirestoreAPI() {
  console.log('2️⃣  Test Firestore API...');
  try {
    const url = `https://firestore.googleapis.com/v1/projects/${CONFIG.projectId}/databases/(default)/documents/_test/connection`;
    const response = await httpRequest(url);

    if (response.statusCode === 200) {
      console.log('   ✅ Firestore API: OK (document accessible)\n');
      return true;
    } else if (response.statusCode === 404) {
      console.log('   ✅ Firestore API: OK (document non trouvé - normal)\n');
      return true;
    } else if (response.statusCode === 403) {
      console.log('   ⚠️  Firestore: Accès refusé (vérifier les règles de sécurité)\n');
      return true; // API fonctionne, juste les règles qui bloquent
    }
    
    console.log(`   ⚠️  HTTP ${response.statusCode}\n`);
    return false;
  } catch (error) {
    console.log(`   ❌ Erreur: ${error.message}\n`);
    return false;
  }
}

// Test 3: Firebase Functions
async function testFunctionsAPI() {
  console.log('3️⃣  Test Firebase Functions...');
  try {
    const url = `https://europe-west1-${CONFIG.projectId}.cloudfunctions.net/trackUserLogin`;
    const response = await httpRequest(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: '{}'
    });

    if (response.statusCode === 401 || response.statusCode === 403) {
      console.log('   ✅ Functions déployées (Auth requise)');
      console.log(`   URL: ${url}\n`);
      return true;
    } else if (response.statusCode === 404) {
      console.log('   ⚠️  Function non trouvée ou non déployée\n');
      return false;
    } else if (response.statusCode === 200) {
      console.log('   ✅ Functions accessibles\n');
      return true;
    }
    
    console.log(`   ⚠️  HTTP ${response.statusCode}\n`);
    return false;
  } catch (error) {
    console.log(`   ❌ Erreur: ${error.message}\n`);
    return false;
  }
}

// Test 4: Storage
async function testStorageAPI() {
  console.log('4️⃣  Test Firebase Storage...');
  try {
    const url = `https://firebasestorage.googleapis.com/v0/b/${CONFIG.storageBucket}/o`;
    const response = await httpRequest(url);

    if (response.statusCode === 200) {
      console.log('   ✅ Storage API: OK\n');
      return true;
    } else if (response.statusCode === 403) {
      console.log('   ⚠️  Storage: Accès refusé (vérifier les règles)\n');
      return true;
    }
    
    console.log(`   ⚠️  HTTP ${response.statusCode}\n`);
    return false;
  } catch (error) {
    console.log(`   ❌ Erreur: ${error.message}\n`);
    return false;
  }
}

// Test 5: Connectivité
async function testConnectivity() {
  console.log('5️⃣  Test connectivité Firebase...');
  try {
    const url = 'https://www.gstatic.com/firebasejs/ui/6.1.0/firebase-ui-auth.js';
    const response = await httpRequest(url);

    if (response.statusCode === 200) {
      console.log('   ✅ Connectivité Firebase: OK\n');
      return true;
    }
    
    console.log('   ❌ Problème de connectivité\n');
    return false;
  } catch (error) {
    console.log(`   ❌ Erreur: ${error.message}\n`);
    return false;
  }
}

// Exécution de tous les tests
async function runAllTests() {
  const results = {
    auth: await testAuthAPI(),
    firestore: await testFirestoreAPI(),
    functions: await testFunctionsAPI(),
    storage: await testStorageAPI(),
    connectivity: await testConnectivity(),
  };

  console.log('═══════════════════════════════════════════════════');
  console.log('📊 RÉSUMÉ DES TESTS');
  console.log('═══════════════════════════════════════════════════\n');
  
  const passed = Object.values(results).filter(r => r).length;
  const total = Object.keys(results).length;
  
  console.log(`✅ Tests réussis: ${passed}/${total}\n`);
  
  if (passed === total) {
    console.log('🎉 Toutes les APIs Firebase sont opérationnelles!\n');
  } else {
    console.log('⚠️  Certains tests ont échoué. Vérifiez la configuration.\n');
  }
  
  console.log('💡 Prochaines étapes:');
  console.log('   1. Firebase Console: https://console.firebase.google.com');
  console.log('   2. Activer Authentication → Sign-in method → Google');
  console.log('   3. Vérifier les domaines autorisés');
  console.log('   4. Déployer Functions: firebase deploy --only functions\n');
  
  process.exit(passed === total ? 0 : 1);
}

runAllTests();
