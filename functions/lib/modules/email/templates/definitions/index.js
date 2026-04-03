"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.emailTemplateRegistry = exports.modularEmailTemplateRegistry = exports.modularEmailTemplates = void 0;
exports.getModularEmailTemplate = getModularEmailTemplate;
exports.listModularEmailTemplates = listModularEmailTemplates;
const account_deleted_1 = require("./account_deleted");
const account_deletion_requested_1 = require("./account_deletion_requested");
const account_verified_1 = require("./account_verified");
const first_listing_not_published_1 = require("./first_listing_not_published");
const forgot_password_1 = require("./forgot_password");
const listing_published_1 = require("./listing_published");
const listing_rejected_1 = require("./listing_rejected");
const listing_under_review_1 = require("./listing_under_review");
const login_otp_1 = require("./login_otp");
const message_received_1 = require("./message_received");
const nearby_new_listings_1 = require("./nearby_new_listings");
const password_changed_1 = require("./password_changed");
const payment_confirmed_1 = require("./payment_confirmed");
const payment_failed_1 = require("./payment_failed");
const profile_incomplete_reminder_1 = require("./profile_incomplete_reminder");
const reactivation_30_days_1 = require("./reactivation_30_days");
const referral_invite_1 = require("./referral_invite");
const subscription_expired_1 = require("./subscription_expired");
const subscription_renewed_1 = require("./subscription_renewed");
const verify_email_1 = require("./verify_email");
const welcome_user_1 = require("./welcome_user");
exports.modularEmailTemplates = [
    verify_email_1.verifyEmailTemplate,
    login_otp_1.loginOtpTemplate,
    forgot_password_1.forgotPasswordTemplate,
    password_changed_1.passwordChangedTemplate,
    account_deletion_requested_1.accountDeletionRequestedTemplate,
    account_deleted_1.accountDeletedTemplate,
    welcome_user_1.welcomeUserTemplate,
    profile_incomplete_reminder_1.profileIncompleteReminderTemplate,
    account_verified_1.accountVerifiedTemplate,
    listing_under_review_1.listingUnderReviewTemplate,
    listing_published_1.listingPublishedTemplate,
    listing_rejected_1.listingRejectedTemplate,
    message_received_1.messageReceivedTemplate,
    payment_confirmed_1.paymentConfirmedTemplate,
    payment_failed_1.paymentFailedTemplate,
    subscription_renewed_1.subscriptionRenewedTemplate,
    subscription_expired_1.subscriptionExpiredTemplate,
    first_listing_not_published_1.firstListingNotPublishedTemplate,
    reactivation_30_days_1.reactivation30DaysTemplate,
    nearby_new_listings_1.nearbyNewListingsTemplate,
    referral_invite_1.referralInviteTemplate,
];
exports.modularEmailTemplateRegistry = exports.modularEmailTemplates.reduce((accumulator, template) => {
    accumulator[template.id] = template;
    return accumulator;
}, {});
exports.emailTemplateRegistry = exports.modularEmailTemplateRegistry;
function getModularEmailTemplate(templateId) {
    return exports.modularEmailTemplateRegistry[templateId];
}
function listModularEmailTemplates() {
    return [...exports.modularEmailTemplates];
}
//# sourceMappingURL=index.js.map