import { EmailTemplateDefinition, EmailTemplateId } from "../../contracts";
import { accountDeletedTemplate } from "./account_deleted";
import { accountDeletionRequestedTemplate } from "./account_deletion_requested";
import { accountVerifiedTemplate } from "./account_verified";
import { firstListingNotPublishedTemplate } from "./first_listing_not_published";
import { forgotPasswordTemplate } from "./forgot_password";
import { listingPublishedTemplate } from "./listing_published";
import { listingRejectedTemplate } from "./listing_rejected";
import { listingUnderReviewTemplate } from "./listing_under_review";
import { loginOtpTemplate } from "./login_otp";
import { messageReceivedTemplate } from "./message_received";
import { nearbyNewListingsTemplate } from "./nearby_new_listings";
import { passwordChangedTemplate } from "./password_changed";
import { paymentConfirmedTemplate } from "./payment_confirmed";
import { paymentFailedTemplate } from "./payment_failed";
import { profileIncompleteReminderTemplate } from "./profile_incomplete_reminder";
import { reactivation30DaysTemplate } from "./reactivation_30_days";
import { referralInviteTemplate } from "./referral_invite";
import { subscriptionExpiredTemplate } from "./subscription_expired";
import { subscriptionRenewedTemplate } from "./subscription_renewed";
import { verifyEmailTemplate } from "./verify_email";
import { welcomeUserTemplate } from "./welcome_user";

export const modularEmailTemplates = [
  verifyEmailTemplate,
  loginOtpTemplate,
  forgotPasswordTemplate,
  passwordChangedTemplate,
  accountDeletionRequestedTemplate,
  accountDeletedTemplate,
  welcomeUserTemplate,
  profileIncompleteReminderTemplate,
  accountVerifiedTemplate,
  listingUnderReviewTemplate,
  listingPublishedTemplate,
  listingRejectedTemplate,
  messageReceivedTemplate,
  paymentConfirmedTemplate,
  paymentFailedTemplate,
  subscriptionRenewedTemplate,
  subscriptionExpiredTemplate,
  firstListingNotPublishedTemplate,
  reactivation30DaysTemplate,
  nearbyNewListingsTemplate,
  referralInviteTemplate,
] as const satisfies readonly EmailTemplateDefinition[];

export const modularEmailTemplateRegistry: Record<EmailTemplateId, EmailTemplateDefinition> =
  modularEmailTemplates.reduce<Record<EmailTemplateId, EmailTemplateDefinition>>((accumulator, template) => {
    accumulator[template.id] = template;
    return accumulator;
  }, {} as Record<EmailTemplateId, EmailTemplateDefinition>);

export const emailTemplateRegistry = modularEmailTemplateRegistry;

export function getModularEmailTemplate(templateId: EmailTemplateId): EmailTemplateDefinition {
  return modularEmailTemplateRegistry[templateId];
}

export function listModularEmailTemplates(): EmailTemplateDefinition[] {
  return [...modularEmailTemplates];
}