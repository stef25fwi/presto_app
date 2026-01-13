#!/usr/bin/env node

/**
 * Script de suppression de toutes les annonces (collection 'offers')
 * ⚠️ DESTRUCTIF ET IRRÉVERSIBLE
 */

import admin from 'firebase-admin';

// Initialiser Firebase Admin SDK avec les credentials par défaut
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function deleteAllOffers() {
  console.log('🚨 DÉBUT DE SUPPRESSION DE TOUTES LES ANNONCES');
  console.log('⏳ Connexion à Firestore...\n');

  try {
    // 1) Compter les documents avant suppression
    const countBefore = await db.collection('offers').count().get();
    const totalDocs = countBefore.data().count;
    console.log(`📊 Total d'annonces à supprimer: ${totalDocs}`);

    if (totalDocs === 0) {
      console.log('✅ Aucune annonce à supprimer.');
      process.exit(0);
    }

    // 2) Supprimer par batch (Firestore a une limite de 500 docs par transaction)
    const batchSize = 100;
    let deleted = 0;

    while (deleted < totalDocs) {
      const snapshot = await db.collection('offers').limit(batchSize).get();
      
      if (snapshot.empty) {
        console.log('✅ Toutes les annonces ont été supprimées!');
        break;
      }

      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      deleted += snapshot.docs.length;
      console.log(`🗑️  ${deleted}/${totalDocs} annonces supprimées...`);
    }

    console.log('\n✅ SUPPRESSION TERMINÉE avec succès!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur lors de la suppression:', error);
    process.exit(1);
  }
}

deleteAllOffers();
