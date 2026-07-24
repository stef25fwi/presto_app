"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AdminBulkListingInputError = exports.ADMIN_BULK_LISTING_DELETE_CONCURRENCY = exports.ADMIN_BULK_LISTING_DELETE_MAX_IDS = void 0;
exports.normalizeAdminBulkListingIds = normalizeAdminBulkListingIds;
exports.executeAdminBulkListingDeletion = executeAdminBulkListingDeletion;
exports.ADMIN_BULK_LISTING_DELETE_MAX_IDS = 50;
exports.ADMIN_BULK_LISTING_DELETE_CONCURRENCY = 5;
class AdminBulkListingInputError extends Error {
    constructor(message) {
        super(message);
        this.name = "AdminBulkListingInputError";
    }
}
exports.AdminBulkListingInputError = AdminBulkListingInputError;
function normalizeString(value) {
    return String(value ?? "").trim();
}
function normalizeAdminBulkListingIds(value, maxIds = exports.ADMIN_BULK_LISTING_DELETE_MAX_IDS) {
    if (!Array.isArray(value)) {
        throw new AdminBulkListingInputError("listingIds must be an array");
    }
    if (!Number.isInteger(maxIds) || maxIds <= 0) {
        throw new AdminBulkListingInputError("maxIds must be a positive integer");
    }
    const seen = new Set();
    const listingIds = [];
    for (const rawId of value) {
        const listingId = normalizeString(rawId);
        if (!listingId || seen.has(listingId))
            continue;
        seen.add(listingId);
        listingIds.push(listingId);
    }
    if (listingIds.length === 0) {
        throw new AdminBulkListingInputError("at least one listingId is required");
    }
    if (listingIds.length > maxIds) {
        throw new AdminBulkListingInputError(`no more than ${maxIds} listingIds are allowed`);
    }
    return listingIds;
}
function readErrorCode(error) {
    if (error && typeof error === "object" && "code" in error) {
        const code = normalizeString(error.code);
        if (code)
            return code;
    }
    return "internal";
}
function readErrorMessage(error) {
    if (error instanceof Error) {
        const message = normalizeString(error.message);
        if (message)
            return message.slice(0, 300);
    }
    return "Unable to delete listing";
}
async function executeAdminBulkListingDeletion({ listingIds, deleteOne, concurrency = exports.ADMIN_BULK_LISTING_DELETE_CONCURRENCY, }) {
    if (!Number.isInteger(concurrency) || concurrency <= 0) {
        throw new AdminBulkListingInputError("concurrency must be a positive integer");
    }
    const results = [];
    for (let index = 0; index < listingIds.length; index += concurrency) {
        const chunk = listingIds.slice(index, index + concurrency);
        const chunkResults = await Promise.all(chunk.map(async (listingId) => {
            try {
                await deleteOne(listingId);
                return { listingId, ok: true };
            }
            catch (error) {
                return {
                    listingId,
                    ok: false,
                    errorCode: readErrorCode(error),
                    errorMessage: readErrorMessage(error),
                };
            }
        }));
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
//# sourceMappingURL=admin_bulk_listing_policy.js.map