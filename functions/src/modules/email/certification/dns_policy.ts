/**
 * Contrôles DNS publics du domaine d'envoi : SPF, DKIM et DMARC.
 *
 * Brevo expose son propre statut de vérification, mais ce statut ne prouve ni
 * qu'un enregistrement est toujours publié, ni qu'il est unique, ni que sa
 * syntaxe est valide. Ces fonctions travaillent sur des chaînes déjà résolues :
 * la résolution DNS elle-même reste dans les scripts de certification.
 */

export const BREVO_SPF_INCLUDES = ["spf.brevo.com", "spf.sendinblue.com"] as const;

const SPF_LOOKUP_MECHANISMS = ["include", "a", "mx", "ptr", "exists", "redirect"] as const;
const SPF_MAX_LOOKUPS = 10;
const DMARC_POLICIES = ["none", "quarantine", "reject"] as const;

export type DmarcPolicy = (typeof DMARC_POLICIES)[number];

export interface SpfAssessment {
  readonly ok: boolean;
  readonly records: readonly string[];
  readonly record: string | null;
  readonly includesProvider: boolean;
  readonly providerMechanism: string | null;
  readonly allQualifier: string | null;
  readonly lookupCount: number;
  readonly issues: readonly string[];
  readonly warnings: readonly string[];
}

export interface DmarcAssessment {
  readonly ok: boolean;
  readonly records: readonly string[];
  readonly record: string | null;
  readonly tags: Readonly<Record<string, string>>;
  readonly policy: string | null;
  readonly subdomainPolicy: string | null;
  readonly percentage: number | null;
  readonly rua: readonly string[];
  readonly ruf: readonly string[];
  readonly issues: readonly string[];
  readonly warnings: readonly string[];
}

export interface DkimExpectation {
  readonly host: string;
  readonly type: string;
  readonly value: string;
  /** Statut renvoyé par Brevo pour cet enregistrement, quand il est connu. */
  readonly providerStatus?: boolean;
}

export interface DkimResolution {
  readonly host: string;
  readonly values: readonly string[];
}

export interface DkimEntryAssessment {
  readonly host: string;
  readonly type: string;
  readonly expected: string;
  readonly resolved: readonly string[];
  readonly published: boolean;
  readonly providerValidated: boolean;
  readonly issues: readonly string[];
}

export interface DkimAssessment {
  readonly ok: boolean;
  readonly entries: readonly DkimEntryAssessment[];
  readonly issues: readonly string[];
  readonly warnings: readonly string[];
}

export interface SenderDnsAssessment {
  readonly domain: string;
  readonly ok: boolean;
  readonly spf: SpfAssessment;
  readonly dkim: DkimAssessment;
  readonly dmarc: DmarcAssessment;
  readonly issues: readonly string[];
  readonly warnings: readonly string[];
}

export interface SpfOptions {
  /** Mécanismes `include:` acceptés comme autorisation Brevo. */
  readonly providerIncludes?: readonly string[];
}

export interface DmarcOptions {
  /**
   * Boîtes réellement surveillées. Une adresse `rua`/`ruf` hors de cette liste
   * signifie que des rapports partent vers une boîte que personne ne lit.
   */
  readonly monitoredMailboxes?: readonly string[];
  /** Politique minimale acceptée pour la phase de déploiement en cours. */
  readonly minimumPolicy?: DmarcPolicy;
}

/** Un TXT DNS arrive en fragments de 255 octets qu'il faut recoller sans séparateur. */
export function joinTxtChunks(chunks: readonly string[]): string {
  return chunks.join("").trim();
}

function normalizeDnsValue(value: string): string {
  return value.trim().replace(/^"|"$/g, "").replace(/\.$/, "").toLowerCase();
}

function normalizeMailbox(value: string): string {
  return value.trim().replace(/^mailto:/i, "").replace(/!\d+[kmgt]?$/i, "").toLowerCase();
}

function mailboxDomain(mailbox: string): string {
  return mailbox.slice(mailbox.lastIndexOf("@") + 1);
}

export function assessSpf(
  txtRecords: readonly (readonly string[])[],
  options: SpfOptions = {},
): SpfAssessment {
  const providerIncludes = (options.providerIncludes ?? BREVO_SPF_INCLUDES).map((item) =>
    item.toLowerCase(),
  );
  const flattened = txtRecords.map(joinTxtChunks);
  const records = flattened.filter((record) => /^v=spf1(\s|$)/i.test(record));
  const issues: string[] = [];
  const warnings: string[] = [];

  if (records.length === 0) {
    return {
      ok: false,
      records,
      record: null,
      includesProvider: false,
      providerMechanism: null,
      allQualifier: null,
      lookupCount: 0,
      issues: ["spf_missing"],
      warnings,
    };
  }
  if (records.length > 1) {
    // RFC 7208 : plusieurs SPF sur le même nom rendent l'évaluation permerror.
    issues.push("spf_multiple_records");
  }

  const record = records[0] ?? "";
  const terms = record.split(/\s+/).slice(1).filter((term) => term.length > 0);

  let providerMechanism: string | null = null;
  let lookupCount = 0;
  let allQualifier: string | null = null;

  for (const term of terms) {
    const lower = term.toLowerCase();
    const withoutQualifier = lower.replace(/^[+\-~?]/, "");
    const mechanism = withoutQualifier.split(":")[0] ?? "";
    const target = withoutQualifier.slice(mechanism.length + 1);

    if (withoutQualifier === "all") {
      allQualifier = /^[+\-~?]/.test(lower) ? lower : `+${lower}`;
      continue;
    }
    if ((SPF_LOOKUP_MECHANISMS as readonly string[]).includes(mechanism)) {
      lookupCount += 1;
    }
    if (mechanism === "include" && providerIncludes.includes(target)) {
      providerMechanism = term;
    }
  }

  if (!providerMechanism) issues.push("spf_brevo_missing");
  if (allQualifier === null) {
    issues.push("spf_all_missing");
  } else if (allQualifier === "+all") {
    issues.push("spf_all_permissive");
  } else if (allQualifier === "?all") {
    warnings.push("spf_all_neutral");
  }
  if (lookupCount > SPF_MAX_LOOKUPS) issues.push("spf_lookup_limit_exceeded");

  return {
    ok: issues.length === 0,
    records,
    record,
    includesProvider: providerMechanism !== null,
    providerMechanism,
    allQualifier,
    lookupCount,
    issues,
    warnings,
  };
}

export function parseDmarcTags(record: string): Record<string, string> {
  const tags: Record<string, string> = {};
  for (const part of record.split(";")) {
    const trimmed = part.trim();
    if (trimmed.length === 0) continue;
    const separator = trimmed.indexOf("=");
    if (separator <= 0) continue;
    const key = trimmed.slice(0, separator).trim().toLowerCase();
    tags[key] = trimmed.slice(separator + 1).trim();
  }
  return tags;
}

export function assessDmarc(
  txtRecords: readonly (readonly string[])[],
  domain: string,
  options: DmarcOptions = {},
): DmarcAssessment {
  const monitored = (options.monitoredMailboxes ?? []).map((item) => normalizeMailbox(item));
  const minimumPolicy = options.minimumPolicy ?? "none";
  const flattened = txtRecords.map(joinTxtChunks);
  const records = flattened.filter((record) => /^v=dmarc1(\s*;|$)/i.test(record));
  const issues: string[] = [];
  const warnings: string[] = [];

  if (records.length === 0) {
    return {
      ok: false,
      records,
      record: null,
      tags: {},
      policy: null,
      subdomainPolicy: null,
      percentage: null,
      rua: [],
      ruf: [],
      issues: ["dmarc_missing"],
      warnings,
    };
  }
  if (records.length > 1) issues.push("dmarc_multiple_records");

  const record = records[0] ?? "";
  const tags = parseDmarcTags(record);
  const policy = tags.p ? tags.p.toLowerCase() : null;
  const subdomainPolicy = tags.sp ? tags.sp.toLowerCase() : null;

  if (!policy) {
    issues.push("dmarc_policy_missing");
  } else if (!(DMARC_POLICIES as readonly string[]).includes(policy)) {
    issues.push("dmarc_policy_invalid");
  } else if (
    DMARC_POLICIES.indexOf(policy as DmarcPolicy) < DMARC_POLICIES.indexOf(minimumPolicy)
  ) {
    issues.push("dmarc_policy_below_minimum");
  }

  if (subdomainPolicy && !(DMARC_POLICIES as readonly string[]).includes(subdomainPolicy)) {
    issues.push("dmarc_subdomain_policy_invalid");
  }

  let percentage: number | null = null;
  if (tags.pct !== undefined) {
    const parsed = Number(tags.pct);
    if (!Number.isInteger(parsed) || parsed < 0 || parsed > 100) {
      issues.push("dmarc_pct_invalid");
    } else {
      percentage = parsed;
      if (parsed < 100) warnings.push("dmarc_pct_partial");
    }
  }

  const parseReportList = (value: string | undefined, tag: "rua" | "ruf"): string[] => {
    if (!value) return [];
    const entries = value.split(",").map((item) => item.trim()).filter((item) => item.length > 0);
    const validMailboxes: string[] = [];
    for (const entry of entries) {
      if (!/^mailto:[^@\s]+@[^@\s]+$/i.test(entry.replace(/!\d+[kmgt]?$/i, ""))) {
        issues.push(`dmarc_${tag}_invalid`);
        continue;
      }
      const mailbox = normalizeMailbox(entry);
      validMailboxes.push(mailbox);
      if (mailboxDomain(mailbox) !== domain.toLowerCase()) {
        // Une boîte hors domaine exige un enregistrement d'autorisation
        // `<domaine>._report._dmarc.<hôte>` côté destinataire.
        warnings.push(`dmarc_${tag}_external_domain`);
      }
    }
    // Plusieurs destinataires sont autorisés par le RFC (ex. garder celui de
    // Brevo tout en ajoutant le sien) : n'exiger qu'un seul destinataire
    // surveillé parmi la liste, pas que tous le soient.
    if (monitored.length > 0 && validMailboxes.length > 0 && !validMailboxes.some((mailbox) => monitored.includes(mailbox))) {
      issues.push(`dmarc_${tag}_unmonitored`);
    }
    return entries;
  };

  const rua = parseReportList(tags.rua, "rua");
  const ruf = parseReportList(tags.ruf, "ruf");
  if (rua.length === 0) warnings.push("dmarc_rua_absent");

  return {
    ok: issues.length === 0,
    records,
    record,
    tags,
    policy,
    subdomainPolicy,
    percentage,
    rua,
    ruf,
    issues,
    warnings,
  };
}

export function assessDkim(
  expectations: readonly DkimExpectation[],
  resolutions: readonly DkimResolution[],
): DkimAssessment {
  const issues: string[] = [];
  const warnings: string[] = [];

  if (expectations.length === 0) {
    return { ok: false, entries: [], issues: ["dkim_expectations_missing"], warnings };
  }

  const resolvedByHost = new Map<string, readonly string[]>();
  for (const resolution of resolutions) {
    resolvedByHost.set(normalizeDnsValue(resolution.host), resolution.values);
  }

  const entries: DkimEntryAssessment[] = expectations.map((expectation) => {
    const host = normalizeDnsValue(expectation.host);
    const expected = normalizeDnsValue(expectation.value);
    const resolved = resolvedByHost.get(host) ?? [];
    const entryIssues: string[] = [];

    const published = resolved.some((value) => {
      const candidate = normalizeDnsValue(value);
      return candidate === expected || candidate.includes(expected) || expected.includes(candidate);
    });

    if (resolved.length === 0) {
      entryIssues.push("dkim_record_missing");
    } else if (!published) {
      entryIssues.push("dkim_record_mismatch");
    }
    if (expectation.providerStatus === false) entryIssues.push("dkim_provider_status_pending");

    for (const entryIssue of entryIssues) {
      if (!issues.includes(entryIssue)) issues.push(entryIssue);
    }

    return {
      host: expectation.host,
      type: expectation.type,
      expected: expectation.value,
      resolved,
      published,
      providerValidated: expectation.providerStatus !== false,
      issues: entryIssues,
    };
  });

  return { ok: issues.length === 0, entries, issues, warnings };
}

export function assessSenderDns(input: {
  readonly domain: string;
  readonly spfTxt: readonly (readonly string[])[];
  readonly dmarcTxt: readonly (readonly string[])[];
  readonly dkimExpectations: readonly DkimExpectation[];
  readonly dkimResolutions: readonly DkimResolution[];
  readonly spfOptions?: SpfOptions;
  readonly dmarcOptions?: DmarcOptions;
}): SenderDnsAssessment {
  const spf = assessSpf(input.spfTxt, input.spfOptions);
  const dkim = assessDkim(input.dkimExpectations, input.dkimResolutions);
  const dmarc = assessDmarc(input.dmarcTxt, input.domain, input.dmarcOptions);

  const issues = [
    ...spf.issues.map((issue) => `spf:${issue}`),
    ...dkim.issues.map((issue) => `dkim:${issue}`),
    ...dmarc.issues.map((issue) => `dmarc:${issue}`),
  ];
  const warnings = [
    ...spf.warnings.map((warning) => `spf:${warning}`),
    ...dkim.warnings.map((warning) => `dkim:${warning}`),
    ...dmarc.warnings.map((warning) => `dmarc:${warning}`),
  ];

  return { domain: input.domain, ok: issues.length === 0, spf, dkim, dmarc, issues, warnings };
}
