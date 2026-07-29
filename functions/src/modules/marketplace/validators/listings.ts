import type { ListingMedia } from "../models/firestore";
import type { MessageReportReasonCode, ReportReasonCode, UserRole } from "../constants/enums";
import { MESSAGE_REPORT_REASON_CODES, REPORT_REASON_CODES, USER_ROLES } from "../constants/enums";
import { ValidationError } from "../services/errors";

type UnknownRecord = Record<string, unknown>;

export interface ValidatedListingDraftPayload {
  title: string;
  description: string;
  price: number;
  categoryId: string;
  cityId: string;
  media: ListingMedia[];
  thumbnailUrl: string;
  searchKeywords: string[];
  phone: string;
  hidePhone: boolean;
  budgetType: string;
  missionDelay: string;
  isUrgent: boolean;
  subCategory: string;
  category: string;
  city: string;
  location: string;
  postalCode: string;
  cp: string;
  dept: string;
  region: string;
  cityCategoryKey: string;
  budgetValue?: number;
}

function inferImageMimeTypeFromPath(storagePath: string): string {
  const normalizedStoragePath = storagePath.toLowerCase();
  if (normalizedStoragePath.endsWith(".webp")) return "image/webp";
  if (normalizedStoragePath.endsWith(".png")) return "image/png";
  if (normalizedStoragePath.endsWith(".heic") || normalizedStoragePath.endsWith(".heif")) {
    return "image/heic";
  }
  if (normalizedStoragePath.endsWith(".gif")) return "image/gif";
  if (normalizedStoragePath.endsWith(".bmp")) return "image/bmp";
  if (normalizedStoragePath.endsWith(".tif") || normalizedStoragePath.endsWith(".tiff")) {
    return "image/tiff";
  }
  if (normalizedStoragePath.endsWith(".avif")) return "image/avif";
  if (normalizedStoragePath.endsWith(".jpeg") || normalizedStoragePath.endsWith(".jpg")) {
    return "image/jpeg";
  }
  return "";
}

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

function assertCondition(condition: boolean, message: string, issues: string[]): void {
  if (!condition) {
    issues.push(message);
  }
}

export function buildSearchKeywords(...values: string[]): string[] {
  const tokens = values
    .flatMap((value) => value.toLowerCase().split(/[^a-z0-9]+/i))
    .map((value) => value.trim())
    .filter((value) => value.length >= 2);
  return Array.from(new Set(tokens)).slice(0, 80);
}

export function validateListingMedia(rawMedia: unknown, maxMediaCount: number): ListingMedia[] {
  if (!Array.isArray(rawMedia)) {
    throw new ValidationError("Listing media must be an array");
  }

  if (rawMedia.length > maxMediaCount) {
    throw new ValidationError(`Too many photos, maximum is ${maxMediaCount}`);
  }

  return rawMedia.map((entry, index) => {
    const media = (entry ?? {}) as UnknownRecord;
    const storagePath = normalizeString(media.storagePath);
    const downloadUrl = normalizeString(media.downloadUrl);
    const thumbnailUrl = normalizeString(media.thumbnailUrl) || downloadUrl;
    const normalizedStoragePath = storagePath.toLowerCase();
    const resolvedMimeType = (normalizeString(media.mimeType) || inferImageMimeTypeFromPath(storagePath))
        .toLowerCase();
    if (!storagePath || !downloadUrl) {
      throw new ValidationError(`Photo #${index + 1} is missing storagePath or downloadUrl`);
    }
    if (!resolvedMimeType.startsWith("image/")) {
      throw new ValidationError(`Photo #${index + 1} must be an image file`);
    }

    const normalizedMedia: ListingMedia = {
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

export function validateListingDraftPayload(rawDraft: UnknownRecord, maxMediaCount: number): ValidatedListingDraftPayload {
  const issues: string[] = [];
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

  let media: ListingMedia[] = [];
  try {
    media = validateListingMedia(rawDraft.media, maxMediaCount);
  } catch (error) {
    if (error instanceof ValidationError) {
      issues.push(...error.issues);
    } else {
      issues.push("Invalid media payload");
    }
  }

  if (issues.length > 0) {
    throw new ValidationError("Draft payload is invalid", issues);
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

export function validateListingReportPayload(rawData: UnknownRecord): {
  listingId: string;
  reasonCode: ReportReasonCode;
  reasonText?: string;
} {
  const listingId = normalizeString(rawData.listingId);
  const reasonCode = normalizeString(rawData.reasonCode) as ReportReasonCode;
  const reasonText = normalizeString(rawData.reasonText);

  if (!listingId) {
    throw new ValidationError("listingId is required");
  }
  if (!REPORT_REASON_CODES.includes(reasonCode)) {
    throw new ValidationError("reasonCode is invalid");
  }
  if (reasonText.length > 800) {
    throw new ValidationError("reasonText is too long");
  }

  return {
    listingId,
    reasonCode,
    reasonText: reasonText || undefined,
  };
}

export function validateConversationReportPayload(rawData: UnknownRecord): {
  conversationId: string;
  messageId?: string;
  reasonCode: MessageReportReasonCode;
  reasonText?: string;
} {
  const conversationId = normalizeString(rawData.conversationId);
  const messageId = normalizeString(rawData.messageId);
  const reasonCode = normalizeString(rawData.reasonCode) as MessageReportReasonCode;
  const reasonText = normalizeString(rawData.reasonText);

  if (!conversationId) {
    throw new ValidationError("conversationId is required");
  }
  if (!MESSAGE_REPORT_REASON_CODES.includes(reasonCode)) {
    throw new ValidationError("reasonCode is invalid");
  }
  if (reasonText.length > 800) {
    throw new ValidationError("reasonText is too long");
  }

  return {
    conversationId,
    messageId: messageId || undefined,
    reasonCode,
    reasonText: reasonText || undefined,
  };
}

export function validateRoleAssignment(rawRoles: unknown): UserRole[] {
  if (!Array.isArray(rawRoles) || rawRoles.length === 0) {
    throw new ValidationError("roles must be a non-empty array");
  }

  const roles = rawRoles
    .map((value) => normalizeString(value))
    .filter((value): value is UserRole => USER_ROLES.includes(value as UserRole));

  if (roles.length === 0) {
    throw new ValidationError("roles must contain at least one supported role");
  }

  return Array.from(new Set(roles));
}

export function validateChatMessageBody(rawBody: unknown): string {
  const body = normalizeString(rawBody);
  if (body.length < 1) {
    throw new ValidationError("Message body is required");
  }
  if (body.length > 2000) {
    throw new ValidationError("Message body is too long");
  }
  return body;
}