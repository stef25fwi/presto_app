import { readFile, writeFile } from "node:fs/promises";

const listingsPath = "functions/src/modules/marketplace/callables/listings.ts";
const indexPath = "functions/src/index.ts";

const listings = await readFile(listingsPath, "utf8");
const privateSignature = "async function closeOrDeleteListingForOwner({";
const exportedSignature = "export async function closeOrDeleteListingForOwner({";
let nextListings = listings;
if (nextListings.includes(privateSignature)) {
  nextListings = nextListings.replace(privateSignature, exportedSignature);
} else if (!nextListings.includes(exportedSignature)) {
  throw new Error("closeOrDeleteListingForOwner signature not found");
}

const indexSource = await readFile(indexPath, "utf8");
const exportLine =
  'export { adminBulkDeleteListings } from "./modules/marketplace/callables/admin_bulk_listings";';
let nextIndex = indexSource;
if (!nextIndex.includes(exportLine)) {
  const anchor =
    'export { processOfferPhoto } from "./modules/marketplace/callables/media";';
  if (!nextIndex.includes(anchor)) {
    throw new Error("functions index anchor not found");
  }
  nextIndex = nextIndex.replace(anchor, `${exportLine}\n${anchor}`);
}

await writeFile(listingsPath, nextListings, "utf8");
await writeFile(indexPath, nextIndex, "utf8");
console.log("admin bulk listing backend exports applied");
