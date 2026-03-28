import type {
  ChatThreadStatus,
  ListingStatus,
  ListingVisibility,
  ModerationAutoFlag,
  ModerationStatus,
  NotificationType,
  ProductAnalyticsEvent,
  ReportReasonCode,
  ReportStatus,
  UserRole,
} from "../constants/enums";

export type FirestoreTimestamp = FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue | null;

export interface MarketplaceCustomClaims {
  roles: UserRole[];
  primaryRole: UserRole;
  marketplaceAccess: true;
}

export interface UserAccountDoc {
  id: string;
  email: string;
  roles: UserRole[];
  primaryRole: UserRole;
  status: "active" | "restricted" | "suspended" | "banned" | "deleted";
  moderationStrikeCount: number;
  spamScore: number;
  trustedSeller: boolean;
  analyticsConsent: boolean;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  lastRoleSyncAt?: FirestoreTimestamp;
  lastRecaptchaScore?: number;
}

export interface ProfileDoc {
  id: string;
  userId: string;
  displayName: string;
  avatarUrl?: string;
  phoneMasked?: string;
  cityId?: string;
  cityLabel?: string;
  isPro: boolean;
  companyName?: string;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
}

export interface ListingMedia {
  storagePath: string;
  downloadUrl: string;
  thumbnailUrl?: string;
  width?: number;
  height?: number;
  mimeType?: string;
  sizeBytes?: number;
  safeSearchStatus?: "pending" | "clean" | "flagged" | "rejected";
}

export interface ListingDoc {
  id: string;
  ownerId: string;
  title: string;
  description: string;
  price: number;
  categoryId: string;
  cityId: string;
  media: ListingMedia[];
  thumbnailUrl: string;
  status: ListingStatus;
  moderationStatus: ModerationStatus;
  visibility: ListingVisibility;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  publishedAt?: FirestoreTimestamp;
  expiresAt?: FirestoreTimestamp;
  reportCount: number;
  favoriteCount: number;
  viewCount: number;
  contactCount: number;
  isBoosted: boolean;
  boostExpiresAt?: FirestoreTimestamp;
  searchKeywords: string[];
  locationApprox?: {
    lat: number;
    lng: number;
    geohash?: string;
    radiusMeters?: number;
  };
  sourceDraftId?: string;
  riskScore?: number;
}

export interface ListingDraftDoc {
  id: string;
  ownerId: string;
  title: string;
  description: string;
  price: number;
  categoryId: string;
  cityId: string;
  media: ListingMedia[];
  status: "draft" | "ready" | "submitted";
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
  submittedAt?: FirestoreTimestamp;
}

export interface ListingModerationDoc {
  id: string;
  listingId: string;
  ownerId: string;
  safeSearchResult: Record<string, unknown>;
  autoFlags: ModerationAutoFlag[];
  moderationDecision: ModerationStatus;
  moderationReason: string;
  reviewedBy?: string;
  reviewedAt?: FirestoreTimestamp;
  source: "automatic" | "manual" | "hybrid";
  imageScanStatus: "pending" | "completed" | "failed";
  textScanStatus: "pending" | "completed" | "failed";
  riskScore: number;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
}

export interface ListingReportDoc {
  id: string;
  reporterId: string;
  listingId: string;
  reasonCode: ReportReasonCode;
  reasonText?: string;
  status: ReportStatus;
  createdAt: FirestoreTimestamp;
  handledBy?: string;
  handledAt?: FirestoreTimestamp;
  resolution?: string;
}

export interface FavoriteDoc {
  id: string;
  userId: string;
  listingId: string;
  createdAt: FirestoreTimestamp;
}

export interface ChatThreadDoc {
  id: string;
  listingId: string;
  ownerId: string;
  buyerId: string;
  participants: string[];
  status: ChatThreadStatus;
  lastMessageAt?: FirestoreTimestamp;
  lastMessagePreview?: string;
  unreadCountByUser: Record<string, number>;
  blockedBy: Record<string, boolean>;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
}

export interface ChatMessageDoc {
  id: string;
  threadId: string;
  listingId: string;
  senderId: string;
  body: string;
  moderationStatus: "clean" | "flagged" | "blocked";
  createdAt: FirestoreTimestamp;
}

export interface MarketplaceNotificationDoc {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  read: boolean;
  routeName?: string;
  listingId?: string;
  threadId?: string;
  createdAt: FirestoreTimestamp;
  metadata?: Record<string, unknown>;
}

export interface AdminActionDoc {
  id: string;
  actorId: string;
  actorRole: UserRole;
  actionType: string;
  targetType: string;
  targetId: string;
  before?: Record<string, unknown>;
  after?: Record<string, unknown>;
  createdAt: FirestoreTimestamp;
  metadata?: Record<string, unknown>;
}

export interface CategoryDoc {
  id: string;
  slug: string;
  label: string;
  isActive: boolean;
  parentId?: string;
  searchableKeywords: string[];
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
}

export interface CityDoc {
  id: string;
  slug: string;
  label: string;
  postalCodes: string[];
  departmentCode?: string;
  regionCode?: string;
  isActive: boolean;
  geo?: {
    lat: number;
    lng: number;
  };
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
}

export interface AnalyticsSnapshotDoc {
  id: string;
  dateKey: string;
  metricGroup: string;
  metrics: Record<string, number>;
  dimensions?: Record<string, string>;
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
}

export interface AppConfigDoc {
  id: string;
  moderation: {
    autoApproveEnabled: boolean;
    reportReviewThreshold: number;
    bannedTerms: string[];
    riskyTerms: string[];
    maxMediaCount: number;
    maxDraftsPerUser: number;
  };
  antiSpam: {
    maxDraftSubmissionsPerHour: number;
    maxReportsPerDay: number;
    maxMessageStartsPerHour: number;
  };
  createdAt: FirestoreTimestamp;
  updatedAt: FirestoreTimestamp;
}

export interface ProductAnalyticsEventDoc {
  id: string;
  eventName: ProductAnalyticsEvent;
  userId?: string;
  listingId?: string;
  threadId?: string;
  source: "client" | "backend";
  params: Record<string, string | number | boolean | null>;
  createdAt: FirestoreTimestamp;
}