#!/usr/bin/env node

const admin = require('firebase-admin');

// Essayer de charger les credentials depuis les variables d'environnement ou config
try {
  // D'abord, essayer d'initialiser avec le projectId uniquement
  // Si c'est en déploiement, les credentials seront chargées automatiquement
  admin.initializeApp({
    projectId: 'presto-app-74abe'
  });
  
  const db = admin.firestore();
  
  (async () => {
    try {
      console.log('Creating document: settings/microia...');
      
      const result = await db.collection('settings').doc('microia').set({
        mode: "HYBRID",
        fallbackEnabled: true,
        qualityThreshold: 0.62,
        languageCode: "fr-FR"
      });
      
      console.log('✓ Document created successfully!');
      console.log('  Path: settings/microia');
      console.log('  Data:', {
        mode: "HYBRID",
        fallbackEnabled: true,
        qualityThreshold: 0.62,
        languageCode: "fr-FR"
      });
      
      process.exit(0);
    } catch (error) {
      console.error('✗ Error creating document:', error.message);
      process.exit(1);
    }
  })();
  
} catch (error) {
  console.error('✗ Firebase initialization error:', error.message);
  console.error('\nTo use this script, you need to:');
  console.error('1. Run: gcloud auth application-default login');
  console.error('2. Or set GOOGLE_APPLICATION_CREDENTIALS env var');
  process.exit(1);
}
