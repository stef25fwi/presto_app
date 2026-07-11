const productionProjectIds = new Set([
  'presto-app-74abe',
]);

export function evaluatePreviewProject(projectId) {
  const normalized = String(projectId ?? '').trim();
  if (!normalized) {
    return {
      enabled: false,
      reason: 'missing-project-id',
      message: 'Firebase preview skipped: FIREBASE_PROJECT_ID is missing.',
    };
  }
  if (productionProjectIds.has(normalized)) {
    return {
      enabled: false,
      reason: 'production-project-forbidden',
      message:
        `Firebase preview refused: ${normalized} is a production project. ` +
        'Configure a dedicated staging or preview Firebase project.',
    };
  }
  return {
    enabled: true,
    reason: 'safe-preview-project',
    message: `Firebase preview project accepted: ${normalized}.`,
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const result = evaluatePreviewProject(process.env.FIREBASE_PROJECT_ID);
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (result.reason === 'production-project-forbidden') {
    process.exitCode = 2;
  }
}
