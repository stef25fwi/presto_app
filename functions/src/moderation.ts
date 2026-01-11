import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
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
export const logModerationStats = onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    try {
      // Check if admin
      const adminDoc = await admin
        .firestore()
        .collection('admins')
        .doc(request.auth.uid)
        .get();

      if (!adminDoc.exists) {
        throw new HttpsError(
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
      throw new HttpsError(
        'internal',
        'Error getting moderation statistics'
      );
    }
  });

/**
 * Cloud Function callable: Envoi d'email de modération au rejet d'annonce
 */
export const sendModerationEmail = onCall(async (request) => {
  // Vérifier l'authentification
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'User must be authenticated to call this function'
    );
  }

  try {
    const {
      userId,
      email,
      userName = 'Utilisateur',
      offerTitle = 'Votre annonce',
      offerId,
      reason = 'Non conformité',
      message = 'Votre annonce n\'a pas pu être publiée.',
    } = request.data as {
      userId: string;
      email: string;
      userName?: string;
      offerTitle?: string;
      offerId?: string;
      reason?: string;
      message?: string;
    };

    // Valider les données requises
    if (!email || !userId) {
      throw new HttpsError(
        'invalid-argument',
        'Email et userId sont requis'
      );
    }

    // Récupérer les credentials Gmail
    const user = await gmailUser.value();
    const pass = await gmailPassword.value();

    // Créer le transporter Nodemailer
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user,
        pass,
      },
    });

    // Générer le HTML de l'email
    const emailHtml = `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #FF6600; color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center; }
            .content { background-color: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
            .reason-box { background-color: #fff; border-left: 4px solid #FF6600; padding: 15px; margin: 15px 0; }
            .footer { color: #666; font-size: 12px; margin-top: 20px; text-align: center; }
            .button { background-color: #FF6600; color: white; padding: 10px 20px; border-radius: 5px; text-decoration: none; display: inline-block; margin: 10px 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Notification de modération</h1>
            </div>
            <div class="content">
              <p>Bonjour <strong>${userName}</strong>,</p>
              
              <p>Nous vous contactons concernant votre annonce :</p>
              <p><strong>"${offerTitle}"</strong></p>
              
              <div class="reason-box">
                <p><strong>Statut :</strong> Rejetée ❌</p>
                <p><strong>Raison :</strong> ${reason}</p>
              </div>
              
              <p>${message}</p>
              
              <h3>Que faire ?</h3>
              <ul>
                <li>Relisez vos informations</li>
                <li>Assurez-vous que votre annonce respecte nos <a href="https://presto-app.fr/cgu">Conditions d'Utilisation</a></li>
                <li>Reformulez votre annonce si nécessaire</li>
                <li>Renvoyez-la pour validation</li>
              </ul>
              
              <p>Pour toute question, n'hésitez pas à <a href="mailto:support@presto-app.fr">contacter notre équipe de support</a>.</p>
              
              <p>Cordialement,<br><strong>L'équipe iliprestō</strong></p>
              
              <div class="footer">
                <p>ID Annonce: ${offerId}</p>
                <p>Cet email a été envoyé automatiquement. Merci de ne pas y répondre directement.</p>
              </div>
            </div>
          </div>
        </body>
      </html>
    `;

    // Envoyer l'email
    await transporter.sendMail({
      from: user,
      to: email,
      subject: `Annonce rejetée: "${offerTitle}"`,
      html: emailHtml,
      text: `${message}\n\nRaison: ${reason}\n\nCordialement, L'équipe iliprestō`,
    });

    console.log('Moderation email sent to', email);
    return {
      success: true,
      message: 'Email envoyé avec succès',
      email,
    };
  } catch (error) {
    console.error('Error sending moderation email:', error);
    throw new HttpsError(
      'internal',
      `Erreur lors de l'envoi de l'email: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
});

