function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/gu, '\\$&');
}

function readsBaseUrl(source, siteUrl) {
  const escaped = escapeRegExp(siteUrl.replace(/\/+$/u, ''));
  return new RegExp(
    `(?:const|let)\\s+baseUrl\\s*=\\s*['\"]${escaped}['\"]\\s*;`,
    'u',
  ).test(source);
}

function registersRoute(source, routePath) {
  const escaped = escapeRegExp(routePath);
  return new RegExp(`['\"]${escaped}['\"]\\s*:\\s*\\{`, 'u').test(source);
}

function buildsCanonicalFromRoute(source) {
  return /(?:const|let)\s+canonical\s*=\s*baseUrl\s*\+\s*path\s*;/u.test(
    source,
  );
}

function appliesCanonicalEverywhere(source) {
  const requirements = [
    /setMeta\(\s*['"]link\[rel=[^\n]+canonical[^\n]+['"]\s*,\s*['"]href['"]\s*,\s*canonical\s*\)/u,
    /setMeta\(\s*['"]meta\[property=[^\n]+og:url[^\n]+['"]\s*,\s*['"]content['"]\s*,\s*canonical\s*\)/u,
    /['"]@id['"]\s*:\s*canonical\s*\+\s*['"]#webpage['"]/u,
    /\burl\s*:\s*canonical\b/u,
  ];
  return requirements.every((pattern) => pattern.test(source));
}

export function validateRuntimeSeoRegistry({
  registrySource,
  routePath,
  siteUrl,
}) {
  const source = String(registrySource ?? '');
  const errors = [];
  const routeRegistered = registersRoute(source, routePath);
  const baseUrlRegistered = readsBaseUrl(source, siteUrl);
  const canonicalBuilderRegistered = buildsCanonicalFromRoute(source);
  const canonicalApplicationRegistered = appliesCanonicalEverywhere(source);

  if (!routeRegistered) errors.push('runtime_registry_route_missing');
  if (!baseUrlRegistered) errors.push('runtime_registry_base_url_mismatch');
  if (!canonicalBuilderRegistered) {
    errors.push('runtime_registry_canonical_builder_missing');
  }
  if (!canonicalApplicationRegistered) {
    errors.push('runtime_registry_canonical_application_missing');
  }

  return {
    routeRegistered,
    baseUrlRegistered,
    canonicalBuilderRegistered,
    canonicalApplicationRegistered,
    canonicalRegistered:
      routeRegistered &&
      baseUrlRegistered &&
      canonicalBuilderRegistered &&
      canonicalApplicationRegistered,
    errors,
  };
}
