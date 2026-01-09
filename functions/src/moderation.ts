import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';
import { defineString } from 'firebase-functions/params';

// Define params for Gmail configuration
const gmailUser = defineString('GMAIL_USER');
const gmailPassword = defineString('GMAIL_PASSWORD');

/**
 * Sends moderation warning email when an offer is rejected
 */
export const sendModerationWarningEmail = functions
  .firestore.onDocumentUpdated('offers/{offerId}', async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    // Check if moderation status changed to REJECTED
    const beforeStatus = before?.moderation?.status;
    const afterStatus = after?.moderation?.status;

    if (beforeStatus !== 'REJECTED' && afterStatus === 'REJECTED') {
      try {
        const userId = after?.userId || after?.uid;
        const offerId = event.params.offerId;
        const title = after?.title || 'Sans titre';
        const userMessage = after?.moderation?.userMessage || 'Votre annonce ne respecte pas nos conditions d\'utilisation.';
        
        if (!userId) {
          console.log('No user ID found for offer', offerId);
          return;
        }

        // Get user document to fetch email
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        const userData = userDoc.data();
        const userEmail = userData?.email;

        if (!userEmail) {
          console.log('No email found for user', userId);
          return;
        }

        // Get Gmail credentials from params
        const user = await gmailUser.value();
        const pass = await gmailPassword.value();

        // Create transporter with current params
        const transporter = nodemailer.createTransport({
          service: 'gmail',
          auth: {
            user: user,
            pass: pass,
          },
        });

        // Send email
        await transporter.sendMail({
          from: user,
          to: userEmail,
          subject: `[iliprestō] Annonce non conforme - ${title}`,
          html: `
            <h2>Annonce rejetée</h2>
            <p>Bonjour,</p>
            <p>Votre annonce "<strong>${title}</strong>" n'a pas pu être publiée car elle ne respecte pas nos conditions d'utilisation.</p>
            <p><strong>Raison:</strong> ${userMessage}</p>
            <p>Vous avez la possibilité de reformuler votre annonce et de la renvoyer. Pour toute question, contactez notre équipe de support.</p>
            <p>Cordialement,<br/>L'équipe iliprestō</p>
          `,
        });

        console.log('Moderation warning email sent to', userEmail);
      } catch (error) {
        console.error('Error sending moderation warning email:', error);
        // Don't throw - let the update complete even if email fails
      }
    }
  });

/**
 * Sends internal message notification when an offer is rejected
 */
export const createModerationMessage = functions
  .firestore.onDocumentUpdated('offers/{offerId}', async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    // Check if moderation status changed to REJECTED
    const beforeStatus = before?.moderation?.status;
    const afterStatus = after?.moderation?.status;

    if (beforeStatus !== 'REJECTED' && afterStatus === 'REJECTED') {
      try {
        const userId = after?.userId || after?.uid;
        const offerId = event.params.offerId;
        const title = after?.title || 'Sans titre';
        const userMessage = after?.moderation?.userMessage || 'Votre annonce ne respecte pas nos conditions d\'utilisation.';

        if (!userId) {
          console.log('No user ID found for offer', offerId);
          return;
        }

        // Create internal notification message
        await admin
          .firestore()
          .collection('notifications')
          .add({
            userId,
            offerId,
            type: 'MODERATION_WARNING',
            title: 'Annonce non conforme',
            message: userMessage,
            actionUrl: `/offers/${offerId}`,
            severity: 'warning',
            read: false,
            createdAt: admin.firestore.Timestamp.now(),
          });

        console.log('Moderation message created for user', userId);
      } catch (error) {
        console.error('Error creating moderation message:', error);
      }
    }
  });

/**
 * Log moderation statistics
 */
export const logModerationStats = functions
  .https.onCall(async (request: any) => {
    const context = request;
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    try {
      // Check if admin
      const adminDoc = await admin
        .firestore()
        .collection('admins')
        .doc(context.auth.uid)
        .get();

      if (!adminDoc.exists) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Admin access required'
        );
      }

      // Get statistics
      const pendingSnap = await admin
        .firestore()
        .collection('offers')
        .where('moderation.status', '==', 'PENDING')
        .get();

      const rejectedSnap = await admin
        .firestore()
        .collection('offers')
        .where('moderation.status', '==', 'REJECTED')
        .get();

      const approvedSnap = await admin
        .firestore()
        .collection('offers')
        .where('moderation.status', '==', 'APPROVED')
        .get();

      return {
        pending: pendingSnap.size,
        rejected: rejectedSnap.size,
        approved: approvedSnap.size,
      };
    } catch (error) {
      console.error('Error getting moderation stats:', error);
      throw new functions.https.HttpsError(
        'internal',
        'Error getting moderation statistics'
      );
    }
  });
