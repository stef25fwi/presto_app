"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildSearchKeywords = buildSearchKeywords;
exports.validateListingMedia = validateListingMedia;
exports.validateListingDraftPayload = validateListingDraftPayload;
exports.validateListingReportPayload = validateListingReportPayload;
exports.validateConversationReportPayload = validateConversationReportPayload;
exports.validateRoleAssignment = validateRoleAssignment;
exports.validateChatMessageBody = validateChatMessageBody;
const enums_1 = require("../constants/enums");
const errors_1 = require("../services/errors");
function inferImageMimeTypeFromPath(storagePath) {
    const normalizedStoragePath = storagePath.toLowerCase();
    if (normalizedStoragePath.endsWith(".webp"))
        return "image/webp";
    if (normalizedStoragePath.endsWith(".png"))
        return "image/png";
    if (normalizedStoragePath.endsWith(".heic") || normalizedStoragePath.endsWith(".heif")) {
        return "image/heic";
    }
    if (normalizedStoragePath.endsWith(".gif"))
        return "image/gif";
    if (normalizedStoragePath.endsWith(".bmp"))
        return "image/bmp";
    if (normalizedStoragePath.endsWith(".tif") || normalizedStoragePath.endsWith(".tiff")) {
        return "image/tiff";
    }
    if (normalizedStoragePath.endsWith(".avif"))
        return "image/avif";
    if (normalizedStoragePath.endsWith(".jpeg") || normalizedStoragePath.endsWith(".jpg")) {
        return "image/jpeg";
    }
    return "";
}
function normalizeString(value) {
    return String(value ?? "").trim();
}
function assertCondition(condition, message, issues) {
    if (!condition) {
        issues.push(message);
    }
}
function buildSearchKeywords(...values) {
    const tokens = values
        .flatMap((value) => value.toLowerCase().split(/[^a-z0-9]+/i))
        .map((value) => value.trim())
        .filter((value) => value.length >= 2);
    return Array.from(new Set(tokens)).slice(0, 80);
}
function validateListingMedia(rawMedia, maxMediaCount) {
    if (!Array.isArray(rawMedia)) {
        throw new errors_1.ValidationError("Listing media must be an array");
    }
    if (rawMedia.length > maxMediaCount) {
        throw new errors_1.ValidationError(`Too many photos, maximum is ${maxMediaCount}`);
    }
    return rawMedia.map((entry, index) => {
        const media = (entry ?? {});
        const storagePath = normalizeString(media.storagePath);
        const downloadUrl = normalizeString(media.downloadUrl);
        const thumbnailUrl = normalizeString(media.thumbnailUrl) || downloadUrl;
        const normalizedStoragePath = storagePath.toLowerCase();
        const resolvedMimeType = (normalizeString(media.mimeType) || inferImageMimeTypeFromPath(storagePath))
            .toLowerCase();
        if (!storagePath || !downloadUrl) {
            throw new errors_1.ValidationError(`Photo #${index + 1} is missing storagePath or downloadUrl`);
        }
        if (!resolvedMimeType.startsWith("image/")) {
            throw new errors_1.ValidationError(`Photo #${index + 1} must be an image file`);
        }
        const normalizedMedia = {
            storagePath,
            downloadUrl,
            thumbnailUrl,
        };
        if (typeof media.width === "number") {
            normalizedMedia.width = media.width;
        }
        if (typeof media.height === "number") {
            normalizedMedia.height = media.height;
        }
        if (resolvedMimeType) {
            normalizedMedia.mimeType = resolvedMimeType;
        }
        if (typeof media.sizeBytes === "number") {
            normalizedMedia.sizeBytes = media.sizeBytes;
        }
        return normalizedMedia;
    });
}
function validateListingDraftPayload(rawDraft, maxMediaCount) {
    const issues = [];
    const title = normalizeString(rawDraft.title);
    const description = normalizeString(rawDraft.description);
    const categoryId = normalizeString(rawDraft.categoryId);
    const cityId = normalizeString(rawDraft.cityId);
    const price = Number(rawDraft.price ?? 0);
    assertCondition(title.length >= 10, "Title must contain at least 10 characters", issues);
    assertCondition(title.length <= 120, "Title must contain at most 120 characters", issues);
    assertCondition(description.length >= 30, "Description must contain at least 30 characters", issues);
    assertCondition(description.length <= 4000, "Description must contain at most 4000 characters", issues);
    assertCondition(Number.isFinite(price) && price >= 0, "Price must be a positive number", issues);
    assertCondition(categoryId.length >= 2, "categoryId is required", issues);
    assertCondition(cityId.length >= 2, "cityId is required", issues);
    let media = [];
    try {
        media = validateListingMedia(rawDraft.media, maxMediaCount);
    }
    catch (error) {
        if (error instanceof errors_1.ValidationError) {
            issues.push(...error.issues);
        }
        else {
            issues.push("Invalid media payload");
        }
    }
    if (issues.length > 0) {
        throw new errors_1.ValidationError("Draft payload is invalid", issues);
    }
    return {
        title,
        description,
        price,
        categoryId,
        cityId,
        media,
        thumbnailUrl: media[0]?.thumbnailUrl || media[0]?.downloadUrl || "",
        searchKeywords: buildSearchKeywords(title, description, categoryId, cityId),
        phone: normalizeString(rawDraft.phone),
        hidePhone: rawDraft.hidePhone === true,
        budgetType: normalizeString(rawDraft.budgetType),
        missionDelay: normalizeString(rawDraft.missionDelay),
        isUrgent: rawDraft.isUrgent === true,
        subCategory: normalizeString(rawDraft.subCategory),
        category: normalizeString(rawDraft.category),
        city: normalizeString(rawDraft.city),
        location: normalizeString(rawDraft.location),
        postalCode: normalizeString(rawDraft.postalCode),
        cp: normalizeString(rawDraft.cp),
        dept: normalizeString(rawDraft.dept),
        region: normalizeString(rawDraft.region),
        cityCategoryKey: normalizeString(rawDraft.cityCategoryKey),
        budgetValue: Number.isFinite(Number(rawDraft.budgetValue))
            ? Number(rawDraft.budgetValue)
            : undefined,
    };
}
function validateListingReportPayload(rawData) {
    const listingId = normalizeString(rawData.listingId);
    const reasonCode = normalizeString(rawData.reasonCode);
    const reasonText = normalizeString(rawData.reasonText);
    if (!listingId) {
        throw new errors_1.ValidationError("listingId is required");
    }
    if (!enums_1.REPORT_REASON_CODES.includes(reasonCode)) {
        throw new errors_1.ValidationError("reasonCode is invalid");
    }
    if (reasonText.length > 800) {
        throw new errors_1.ValidationError("reasonText is too long");
    }
    return {
        listingId,
        reasonCode,
        reasonText: reasonText || undefined,
    };
}
function validateConversationReportPayload(rawData) {
    const conversationId = normalizeString(rawData.conversationId);
    const messageId = normalizeString(rawData.messageId);
    const reasonCode = normalizeString(rawData.reasonCode);
    const reasonText = normalizeString(rawData.reasonText);
    if (!conversationId) {
        throw new errors_1.ValidationError("conversationId is required");
    }
    if (!enums_1.MESSAGE_REPORT_REASON_CODES.includes(reasonCode)) {
        throw new errors_1.ValidationError("reasonCode is invalid");
    }
    if (reasonText.length > 800) {
        throw new errors_1.ValidationError("reasonText is too long");
    }
    return {
        conversationId,
        messageId: messageId || undefined,
        reasonCode,
        reasonText: reasonText || undefined,
    };
}
function validateRoleAssignment(rawRoles) {
    if (!Array.isArray(rawRoles) || rawRoles.length === 0) {
        throw new errors_1.ValidationError("roles must be a non-empty array");
    }
    const roles = rawRoles
        .map((value) => normalizeString(value))
        .filter((value) => enums_1.USER_ROLES.includes(value));
    if (roles.length === 0) {
        throw new errors_1.ValidationError("roles must contain at least one supported role");
    }
    return Array.from(new Set(roles));
}
function validateChatMessageBody(rawBody) {
    const body = normalizeString(rawBody);
    if (body.length < 1) {
        throw new errors_1.ValidationError("Message body is required");
    }
    if (body.length > 2000) {
        throw new errors_1.ValidationError("Message body is too long");
    }
    return body;
}
//# sourceMappingURL=listings.js.map