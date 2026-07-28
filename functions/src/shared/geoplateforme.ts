type JsonRecord = Record<string, unknown>;

function asRecord(value: unknown): JsonRecord {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function asText(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asNumber(value: unknown): number | null {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

export function buildGeoplateformeCompletionUrl(input: string): string {
  const url = new URL("https://data.geopf.fr/geocodage/completion/");
  url.searchParams.set("text", input.trim());
  url.searchParams.set("terr", "DOMTOM,METROPOLE");
  url.searchParams.set("type", "StreetAddress");
  url.searchParams.set("maximumResponses", "8");
  return url.toString();
}

export function buildGeoplateformeSearchUrl(query: string): string {
  const url = new URL("https://data.geopf.fr/geocodage/search");
  url.searchParams.set("q", query.trim());
  url.searchParams.set("limit", "1");
  return url.toString();
}

export function mapGeoplateformeCompletion(value: unknown): {
  status: "OK" | "ZERO_RESULTS";
  predictions: Array<{ description: string; placeId: string }>;
} {
  const root = asRecord(value);
  const results = Array.isArray(root.results) ? root.results : [];
  const seen = new Set<string>();
  const predictions: Array<{ description: string; placeId: string }> = [];

  for (const item of results) {
    const row = asRecord(item);
    const description = asText(row.fulltext) || [
      asText(row.street),
      asText(row.zipcode),
      asText(row.city),
    ].filter(Boolean).join(" ");
    if (!description || seen.has(description)) continue;
    seen.add(description);
    predictions.push({ description, placeId: description });
  }

  return {
    status: predictions.length > 0 ? "OK" : "ZERO_RESULTS",
    predictions,
  };
}

function addressComponent(
  longName: string,
  shortName: string,
  types: string[],
): JsonRecord | null {
  if (!longName) return null;
  return {
    long_name: longName,
    short_name: shortName || longName,
    types,
  };
}

export function mapGeoplateformeSearch(value: unknown): {
  status: "OK" | "ZERO_RESULTS";
  result: JsonRecord | null;
} {
  const root = asRecord(value);
  const features = Array.isArray(root.features) ? root.features : [];
  const feature = asRecord(features[0]);
  const properties = asRecord(feature.properties);
  const geometry = asRecord(feature.geometry);
  const coordinates = Array.isArray(geometry.coordinates)
    ? geometry.coordinates
    : [];

  if (Object.keys(properties).length === 0) {
    return { status: "ZERO_RESULTS", result: null };
  }

  const houseNumber = asText(properties.housenumber);
  const street = asText(properties.street) || asText(properties.name);
  const city = asText(properties.city);
  const postcode = asText(properties.postcode);
  const cityCode = asText(properties.citycode);
  const context = asText(properties.context);
  const department = context.split(",")[0]?.trim() || "";
  const components = [
    addressComponent(houseNumber, houseNumber, ["street_number"]),
    addressComponent(street, street, ["route"]),
    addressComponent(city, cityCode || city, ["locality", "political"]),
    addressComponent(department, department, ["administrative_area_level_2", "political"]),
    addressComponent(postcode, postcode, ["postal_code"]),
    addressComponent("France", "FR", ["country", "political"]),
  ].filter((component): component is JsonRecord => component !== null);

  const longitude = asNumber(coordinates[0] ?? properties.x);
  const latitude = asNumber(coordinates[1] ?? properties.y);

  return {
    status: "OK",
    result: {
      address_components: components,
      formatted_address: asText(properties.label) || [
        houseNumber,
        street,
        postcode,
        city,
      ].filter(Boolean).join(" "),
      geometry: longitude !== null && latitude !== null
        ? { location: { lat: latitude, lng: longitude } }
        : undefined,
      source: "geoplateforme",
    },
  };
}
