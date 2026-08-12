type AnyMap = Record<string, any>;

export type DeclaredLeaderMatch = {
  matched: boolean;
  declaredFirstName: string;
  declaredLastName: string;
  role: string;
};

export function normalizePersonName(value: unknown): string {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[’'\-]/g, " ")
    .replace(/[^A-Za-z\s]/g, " ")
    .toUpperCase()
    .replace(/\s+/g, " ")
    .trim();
}

export function assertDeclaredLeaderNames(
  firstName: unknown,
  lastName: unknown,
): { firstName: string; lastName: string } {
  const cleanFirstName = String(firstName ?? "").trim();
  const cleanLastName = String(lastName ?? "").trim();
  const normalizedFirstName = normalizePersonName(cleanFirstName);
  const normalizedLastName = normalizePersonName(cleanLastName);

  if (normalizedFirstName.length < 2 || normalizedLastName.length < 2) {
    throw new Error("DECLARED_LEADER_NAME_INVALID");
  }

  if (cleanFirstName.length > 100 || cleanLastName.length > 100) {
    throw new Error("DECLARED_LEADER_NAME_INVALID");
  }

  return {
    firstName: cleanFirstName,
    lastName: cleanLastName,
  };
}

function officialLastNames(leader: AnyMap): string[] {
  return [
    leader?.nom,
    leader?.nom_usage,
    leader?.nom_naissance,
    leader?.nom_patronymique,
  ]
    .map(normalizePersonName)
    .filter(Boolean);
}

function officialFirstNames(leader: AnyMap): string[] {
  return [leader?.prenoms, leader?.prenom]
    .map(normalizePersonName)
    .filter(Boolean);
}

function firstNameMatches(declared: string, official: string): boolean {
  if (declared === official) return true;

  // L'API peut renvoyer tous les prénoms de l'état civil alors que le profil
  // ne demande que le prénom usuel/premier prénom déclaré.
  return official.startsWith(`${declared} `);
}

export function matchDeclaredLeader(
  company: AnyMap,
  declaredFirstName: string,
  declaredLastName: string,
): DeclaredLeaderMatch {
  const normalizedFirstName = normalizePersonName(declaredFirstName);
  const normalizedLastName = normalizePersonName(declaredLastName);
  const leaders = Array.isArray(company?.dirigeants) ? company.dirigeants : [];

  for (const leader of leaders) {
    const type = normalizePersonName(leader?.type_dirigeant);
    if (type && !type.includes("PERSONNE PHYSIQUE")) {
      continue;
    }

    const lastNameMatches = officialLastNames(leader).some(
      (official) => official === normalizedLastName,
    );
    if (!lastNameMatches) continue;

    const firstNamesMatch = officialFirstNames(leader).some((official) =>
      firstNameMatches(normalizedFirstName, official),
    );
    if (!firstNamesMatch) continue;

    return {
      matched: true,
      declaredFirstName: declaredFirstName.trim(),
      declaredLastName: declaredLastName.trim(),
      role: String(leader?.qualite ?? leader?.fonction ?? "").trim(),
    };
  }

  return {
    matched: false,
    declaredFirstName: declaredFirstName.trim(),
    declaredLastName: declaredLastName.trim(),
    role: "",
  };
}
