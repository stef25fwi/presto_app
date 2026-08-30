#!/usr/bin/env node
import fs from 'node:fs/promises';
import process from 'node:process';

export function buildBlockedLot17Report({
  commitSha,
  blocker,
  description,
  generatedAt = new Date(),
}) {
  return {
    lot: 17,
    status: 'blocked',
    state: 'failure',
    statusContext: 'quality/campaign-attribution-lot17',
    generatedAt: generatedAt.toISOString(),
    commitSha,
    blocker,
    description,
    checks: [],
    web: null,
    android: null,
    ios: null,
  };
}

export function markdownForBlockedLot17(report) {
  return `# Attribution UTM et deep links — lot 17\n\n- Statut : **blocked**\n- SHA : \`${report.commitSha}\`\n- Contexte GitHub : **${report.statusContext}**\n- Blocage : **${report.blocker}**\n- Détail : ${report.description}\n`;
}

async function main() {
  const commitSha = process.env.DEPLOYED_SHA || process.env.GITHUB_SHA || 'unknown';
  const blocker = process.argv[2] || 'configuration_missing';
  const description = process.argv.slice(3).join(' ') || 'Configuration requise indisponible.';
  const outputDir = 'build/seo';
  const report = buildBlockedLot17Report({ commitSha, blocker, description });

  await fs.mkdir(outputDir, { recursive: true });
  await fs.writeFile(
    `${outputDir}/campaign-attribution-lot17-report.json`,
    `${JSON.stringify(report, null, 2)}\n`,
  );
  await fs.writeFile(
    `${outputDir}/campaign-attribution-lot17-report.md`,
    markdownForBlockedLot17(report),
  );

  console.error(`Lot 17 blocked: ${blocker} — ${description}`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  await main();
}
