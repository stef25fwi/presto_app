function normalize(value) {
  return String(value ?? '').trim();
}

function isCanonicalUid(id) {
  return /^[A-Za-z0-9]{20,40}$/.test(normalize(id));
}

function hasEmail(data) {
  return normalize(data?.email) !== '';
}

function hasProfileFields(data) {
  return Boolean(
    normalize(data?.displayName) ||
        normalize(data?.pseudo) ||
        normalize(data?.phone) ||
        normalize(data?.city),
  );
}

function looksTestEmail(email) {
  return /test|example\.com|presto-app\.test|ilipresto\.dev|pipeline\.analysis/.test(
    normalize(email).toLowerCase(),
  );
}

function looksSeedName(id) {
  return /demo|seed|test/i.test(normalize(id));
}

function classifyUserRecord(id, data) {
  const shortOrNonCanonicalUid = !isCanonicalUid(id);
  const hasCreatedAt = data?.createdAt != null;

  if (looksTestEmail(data?.email) || looksSeedName(id)) {
    return 'test_or_seed';
  }

  if (
    shortOrNonCanonicalUid &&
    !hasEmail(data) &&
    !hasCreatedAt &&
    !hasProfileFields(data)
  ) {
    return 'legacy_stub';
  }

  if (shortOrNonCanonicalUid) {
    return 'noncanonical_but_hydrated';
  }

  return 'canonical_user';
}

function summarizeUserRecord(id, data) {
  return {
    uid: id,
    email: data?.email ?? null,
    accountType: data?.accountType ?? null,
    createdAtType: data?.createdAt?.constructor?.name ?? typeof data?.createdAt,
    subscriptionPlan: data?.subscriptionPlan ?? null,
    subscriptionStatus: data?.subscriptionStatus ?? null,
  };
}

module.exports = {
  classifyUserRecord,
  hasEmail,
  isCanonicalUid,
  normalize,
  summarizeUserRecord,
};