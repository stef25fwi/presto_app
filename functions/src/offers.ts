import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialiser Firebase Admin une seule fois
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Cloud Function HTTP pour activer toutes les offres
 * Ajoute/met à jour isActive: true sur tous les docs de 'offers'
 * 
 * Usage:
 * curl -X POST https://region-project.cloudfunctions.net/activateAllOffers
 * 
 * Retour:
 * {
 *   "success": true,
 *   "updated": 42,
 *   "message": "42 offre(s) activée(s)"
 * }
 */
export const activateAllOffers = functions.https.onRequest(
  async (request, response) => {
    // Vérifier que c'est un POST
    if (request.method !== "POST") {
      response.status(405).json({
        success: false,
        error: "Méthode non autorisée. Utilise POST.",
      });
      return;
    }

    try {
      console.log("🔄 Activation des offres...");

      // Récupérer tous les docs de 'offers'
      const snapshot = await db.collection("offers").get();

      if (snapshot.empty) {
        console.log("Aucune offre trouvée");
        response.json({
          success: true,
          updated: 0,
          message: "Aucune offre trouvée",
        });
        return;
      }

      console.log(`📊 ${snapshot.docs.length} offre(s) trouvée(s)`);

      // Mettre à jour par batch (max 500)
      const batch = db.batch();
      let updated = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();

        // Si isActive n'existe pas ou est false, le mettre à true
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

      // Commit
      if (updated > 0) {
        await batch.commit();
        console.log(`✅ ${updated} offre(s) mises à jour`);
      } else {
        console.log("✅ Toutes les offres sont déjà actives");
      }

      response.json({
        success: true,
        updated,
        message: `${updated} offre(s) activée(s)`,
        total: snapshot.docs.length,
      });
    } catch (error) {
      console.error("❌ Erreur:", error);
      response.status(500).json({
        success: false,
        error: String(error),
      });
    }
  }
);

/**
 * Cloud Function HTTP pour obtenir le statut des offres
 * Retourne le nombre d'offres actives vs inactives
 */
export const offersStatus = functions.https.onRequest(
  async (request, response) => {
    try {
      const snapshot = await db.collection("offers").get();

      const stats = {
        total: snapshot.docs.length,
        active: 0,
        inactive: 0,
        missing: 0,
      };

      for (const doc of snapshot.docs) {
        const data = doc.data();
        if (data.isActive === true) {
          stats.active++;
        } else if (data.isActive === false) {
          stats.inactive++;
        } else {
          stats.missing++;
        }
      }

      response.json({
        success: true,
        stats,
        message: `${stats.active} actives, ${stats.inactive} inactives, ${stats.missing} non défini`,
      });
    } catch (error) {
      console.error("❌ Erreur:", error);
      response.status(500).json({
        success: false,
        error: String(error),
      });
    }
  }
);
