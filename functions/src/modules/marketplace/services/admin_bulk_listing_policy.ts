export const ADMIN_BULK_LISTING_DELETE_MAX_IDS = 50;
export const ADMIN_BULK_LISTING_DELETE_CONCURRENCY = 5;

export class AdminBulkListingInputError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AdminBulkListingInputError";
  }
}

export type AdminBulkListingDeleteResult = {
  listingId: string;
  ok: boolean;
  errorCode?: string;
  errorMessage?: string;
};

export type AdminBulkListingDeleteSummary = {
  requestedCount: number;
  succeededCount: number;
  failedCount: number;
  results: AdminBulkListingDeleteResult[];
};

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

export function normalizeAdminBulkListingIds(
  value: unknown,
  maxIds = ADMIN_BULK_LISTING_DELETE_MAX_IDS,
): string[] {
  if (!Array.isArray(value)) {
    throw new AdminBulkListingInputError("listingIds must be an array");
  }
  if (!Number.isInteger(maxIds) || maxIds <= 0) {
    throw new AdminBulkListingInputError("maxIds must be a positive integer");
  }

  const seen = new Set<string>();
  const listingIds: string[] = [];
  for (const rawId of value) {
    const listingId = normalizeString(rawId);
    if (!listingId || seen.has(listingId)) continue;
    seen.add(listingId);
    listingIds.push(listingId);
  }

  if (listingIds.length === 0) {
    throw new AdminBulkListingInputError("at least one listingId is required");
  }
  if (listingIds.length > maxIds) {
    throw new AdminBulkListingInputError(
      `no more than ${maxIds} listingIds are allowed`,
    );
  }

  return listingIds;
}

function readErrorCode(error: unknown): string {
  if (error && typeof error === "object" && "code" in error) {
    const code = normalizeString((error as { code?: unknown }).code);
    if (code) return code;
  }
  return "internal";
}

function readErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    const message = normalizeString(error.message);
    if (message) return message.slice(0, 300);
  }
  return "Unable to delete listing";
}

export async function executeAdminBulkListingDeletion({
  listingIds,
  deleteOne,
  concurrency = ADMIN_BULK_LISTING_DELETE_CONCURRENCY,
}: {
  listingIds: readonly string[];
  deleteOne: (listingId: string) => Promise<unknown>;
  concurrency?: number;
}): Promise<AdminBulkListingDeleteSummary> {
  if (!Number.isInteger(concurrency) || concurrency <= 0) {
    throw new AdminBulkListingInputError(
      "concurrency must be a positive integer",
    );
  }

  const results: AdminBulkListingDeleteResult[] = [];
  for (let index = 0; index < listingIds.length; index += concurrency) {
    const chunk = listingIds.slice(index, index + concurrency);
    const chunkResults = await Promise.all(
      chunk.map(async (listingId): Promise<AdminBulkListingDeleteResult> => {
        try {
          await deleteOne(listingId);
          return { listingId, ok: true };
        } catch (error) {
          return {
            listingId,
            ok: false,
            errorCode: readErrorCode(error),
            errorMessage: readErrorMessage(error),
          };
        }
      }),
    );
    results.push(...chunkResults);
  }

  const succeededCount = results.filter((result) => result.ok).length;
  return {
    requestedCount: results.length,
    succeededCount,
    failedCount: results.length - succeededCount,
    results,
  };
}
