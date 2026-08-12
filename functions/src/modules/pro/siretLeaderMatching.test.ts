import assert from "node:assert/strict";
import test from "node:test";

import {
  assertDeclaredLeaderNames,
  matchDeclaredLeader,
  normalizePersonName,
} from "./siretLeaderMatching";

test("normalizePersonName neutralise accents, tirets et apostrophes", () => {
  assert.equal(normalizePersonName("  Jean-Pierre d’Été  "), "JEAN PIERRE D ETE");
});

test("matchDeclaredLeader accepte le premier prénom et le nom normalisé", () => {
  const company = {
    dirigeants: [
      {
        nom: "D'ÉTÉ",
        prenoms: "Jean Pierre Louis",
        qualite: "Gérant",
        type_dirigeant: "personne physique",
      },
    ],
  };

  const result = matchDeclaredLeader(company, "Jean-Pierre", "D’Eté");

  assert.equal(result.matched, true);
  assert.equal(result.role, "Gérant");
  assert.equal(result.declaredFirstName, "Jean-Pierre");
  assert.equal(result.declaredLastName, "D’Eté");
});

test("matchDeclaredLeader ignore les dirigeants personnes morales", () => {
  const company = {
    dirigeants: [
      {
        nom: "DUPONT",
        prenoms: "Marie",
        qualite: "Président",
        type_dirigeant: "personne morale",
      },
    ],
  };

  assert.equal(matchDeclaredLeader(company, "Marie", "Dupont").matched, false);
});

test("matchDeclaredLeader refuse un nom ou prénom différent", () => {
  const company = {
    dirigeants: [
      {
        nom: "DUPONT",
        prenoms: "Marie Claire",
        type_dirigeant: "personne physique",
      },
    ],
  };

  assert.equal(matchDeclaredLeader(company, "Jeanne", "Dupont").matched, false);
  assert.equal(matchDeclaredLeader(company, "Marie", "Durand").matched, false);
});

test("assertDeclaredLeaderNames rejette les valeurs absentes ou trop courtes", () => {
  assert.throws(
    () => assertDeclaredLeaderNames("A", "Dupont"),
    /DECLARED_LEADER_NAME_INVALID/,
  );
  assert.throws(
    () => assertDeclaredLeaderNames("Marie", ""),
    /DECLARED_LEADER_NAME_INVALID/,
  );
});
