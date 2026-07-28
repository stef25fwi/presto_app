import assert from "node:assert/strict";
import test from "node:test";

import {
  buildGeoplateformeCompletionUrl,
  buildGeoplateformeSearchUrl,
  mapGeoplateformeCompletion,
  mapGeoplateformeSearch,
} from "./geoplateforme";

test("completion URL covers metropolitan France and overseas territories", () => {
  const url = new URL(buildGeoplateformeCompletionUrl("Baie-Mahault"));
  assert.equal(url.origin, "https://data.geopf.fr");
  assert.equal(url.searchParams.get("terr"), "DOMTOM,METROPOLE");
  assert.equal(url.searchParams.get("maximumResponses"), "8");
});

test("completion mapping keeps the callable response contract", () => {
  assert.deepEqual(mapGeoplateformeCompletion({
    results: [
      { fulltext: "Rue de la République 97122 Baie-Mahault" },
      { fulltext: "Rue de la République 97122 Baie-Mahault" },
      { fulltext: "Rue Frébault 97110 Pointe-à-Pitre" },
    ],
  }), {
    status: "OK",
    predictions: [
      {
        description: "Rue de la République 97122 Baie-Mahault",
        placeId: "Rue de la République 97122 Baie-Mahault",
      },
      {
        description: "Rue Frébault 97110 Pointe-à-Pitre",
        placeId: "Rue Frébault 97110 Pointe-à-Pitre",
      },
    ],
  });
});

test("search mapping exposes Google-compatible address components", () => {
  const mapped = mapGeoplateformeSearch({
    features: [{
      properties: {
        label: "10 Rue Frébault 97110 Pointe-à-Pitre",
        housenumber: "10",
        street: "Rue Frébault",
        postcode: "97110",
        city: "Pointe-à-Pitre",
        citycode: "97120",
        context: "971, Guadeloupe",
      },
      geometry: { coordinates: [-61.534, 16.241] },
    }],
  });
  assert.equal(mapped.status, "OK");
  assert.equal(mapped.result?.formatted_address, "10 Rue Frébault 97110 Pointe-à-Pitre");
  assert.deepEqual(mapped.result?.geometry, {
    location: { lat: 16.241, lng: -61.534 },
  });
  const components = mapped.result?.address_components as Array<Record<string, unknown>>;
  assert.ok(components.some((component) =>
    (component.types as string[]).includes("postal_code") &&
    component.long_name === "97110"
  ));
});

test("empty API responses keep zero-result semantics", () => {
  assert.deepEqual(mapGeoplateformeCompletion({}), {
    status: "ZERO_RESULTS",
    predictions: [],
  });
  assert.deepEqual(mapGeoplateformeSearch({ features: [] }), {
    status: "ZERO_RESULTS",
    result: null,
  });
  assert.match(buildGeoplateformeSearchUrl("Les Abymes"), /limit=1/);
});
