#!/usr/bin/env node

/**
 * Script pour corriger les offres dans Firestore
 * Ajoute/met à jour isActive: true sur toutes les offres
 * Usage: node fix_offers_isactive.js
 */

import * as admin from 'firebase-admin';

// Initialiser Firebase Admin si pas déjà fait
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function fixAllOffers() {
  console.log('🔄 Correction des offres: ajout/mise à jour isActive: true');
  
  try {
    const offersRef = db.collection('offers');
    const snapshot = await offersRef.get();
    
    if (snapshot.empty) {
      console.log('❌ Aucune offre trouvée');
      return;
    }

    console.log(`📊 ${snapshot.docs.length} offre(s) trouvée(s)`);

    let updated = 0;
    let errors = 0;

    const batch = db.batch();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Si isActive n'existe pas OU est false, le mettre à true
      if (!data.isActive || data.isActive === false) {
        console.log(`  ✏️  ${doc.id}: isActive → true`);
        batch.update(doc.ref, {
          isActive: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        updated++;
      } else {
        console.log(`  ✅ ${doc.id}: déjà isActive=true`);
      }
    }

    if (updated === 0) {
      console.log('\n✅ Toutes les offres ont déjà isActive=true');
      return;
    }

    // Commit par batch (500 max)
    await batch.commit();
    console.log(`\n✅ ${updated} offre(s) mises à jour`);

  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

// Si exécuté directement
if (import.meta.url === `file://${process.argv[1]}`) {
  fixAllOffers().then(() => {
    console.log('\n✨ Terminé');
    process.exit(0);
  }).catch(err => {
    console.error(err);
    process.exit(1);
  });
}

export { fixAllOffers };
