const productionProjectIds = new Set([
  'presto-app-74abe',
]);

const previewEnvironmentMarkers = [
  'staging',
  'preview',
  'development',
  'dev',
  'test',
  'qa',
];

function normalizeProjectId(projectId) {
  return String(projectId ?? '').trim().toLowerCase();
}

function hasPreviewEnvironmentMarker(projectId) {
  return previewEnvironmentMarkers.some((marker) =>
    projectId.split('-').includes(marker),
  );
}

export function evaluatePreviewProject(projectId, productionProjectId) {
  const normalized = normalizeProjectId(projectId);
  const normalizedProduction = normalizeProjectId(productionProjectId);
  const forbiddenProjects = new Set(productionProjectIds);
  if (normalizedProduction) forbiddenProjects.add(normalizedProduction);

  if (!normalized) {
    return {
      enabled: false,
      reason: 'missing-project-id',
      message:
        'Firebase preview skipped: FIREBASE_STAGING_PROJECT_ID is missing.',
    };
  }

  if (!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(normalized)) {
    return {
      enabled: false,
      reason: 'invalid-project-id',
      message:
        'Firebase preview refused: FIREBASE_STAGING_PROJECT_ID must be a valid Firebase project ID, not a URL, hostname or alias.',
    };
  }

  if (forbiddenProjects.has(normalized)) {
    return {
      enabled: false,
      reason: 'production-project-forbidden',
      message:
        `Firebase preview refused: ${normalized} is a production project. ` +
        'Configure a dedicated staging or preview Firebase project.',
    };
  }

  if (!hasPreviewEnvironmentMarker(normalized)) {
    return {
      enabled: false,
      reason: 'ambiguous-preview-project',
      message:
        `Firebase preview refused: ${normalized} is not explicitly identified as staging, preview, dev, test or qa. ` +
        'Use a dedicated non-production project with an environment marker in its ID.',
    };
  }

  return {
    enabled: true,
    reason: 'safe-preview-project',
    message: `Firebase preview project accepted: ${normalized}.`,
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const result = evaluatePreviewProject(
    process.env.FIREBASE_STAGING_PROJECT_ID,
    process.env.FIREBASE_PRODUCTION_PROJECT_ID,
  );
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (!result.enabled && result.reason !== 'missing-project-id') {
    process.exitCode = 2;
  }
}
