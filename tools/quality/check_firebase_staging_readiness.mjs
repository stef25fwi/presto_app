import { evaluatePreviewProject } from './check_firebase_preview_project.mjs';

export function evaluateStagingReadiness({ projectId, token }) {
  const project = evaluatePreviewProject(projectId);
  const normalizedToken = String(token ?? '').trim();
  const issues = [];

  if (!project.enabled) issues.push(project.reason);
  if (!normalizedToken) issues.push('missing-staging-token');

  return {
    ready: issues.length === 0,
    projectId: String(projectId ?? '').trim(),
    issues,
    message:
      issues.length === 0
        ? 'Firebase staging credentials are configured for a non-production project.'
        : `Firebase staging is not ready: ${issues.join(', ')}.`,
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const result = evaluateStagingReadiness({
    projectId: process.env.FIREBASE_STAGING_PROJECT_ID,
    token: process.env.FIREBASE_STAGING_TOKEN,
  });
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (!result.ready) process.exitCode = 2;
}
