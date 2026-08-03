import fs from 'node:fs/promises';
import path from 'node:path';

export async function loadSeoMonitoringConfig(
  configPath = 'config/seo-monitoring.json',
) {
  const raw = await fs.readFile(configPath, 'utf8');
  return JSON.parse(raw);
}

export function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

export function shiftUtcDays(date, days) {
  const copy = new Date(date);
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

export function buildComparisonPeriods(config, now = new Date()) {
  const anchor = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  const currentEnd = shiftUtcDays(anchor, -Number(config.dataLagDays ?? 3));
  const currentStart = shiftUtcDays(
    currentEnd,
    -Number(config.currentPeriodDays ?? 28) + 1,
  );
  const previousEnd = shiftUtcDays(currentStart, -1);
  const previousStart = shiftUtcDays(
    previousEnd,
    -Number(config.comparisonPeriodDays ?? 28) + 1,
  );
  return {
    current: { startDate: isoDate(currentStart), endDate: isoDate(currentEnd) },
    previous: {
      startDate: isoDate(previousStart),
      endDate: isoDate(previousEnd),
    },
  };
}

export function numberOrZero(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function percentageChange(current, previous) {
  const currentValue = numberOrZero(current);
  const previousValue = numberOrZero(previous);
  if (previousValue === 0) return currentValue === 0 ? 0 : null;
  return ((currentValue - previousValue) / previousValue) * 100;
}

export function round(value, precision = 2) {
  const numeric = numberOrZero(value);
  const factor = 10 ** precision;
  return Math.round(numeric * factor) / factor;
}

export async function writeJsonFile(filePath, value) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

export async function writeTextFile(filePath, value) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, value, 'utf8');
}

export function safeErrorMessage(error) {
  const message = error instanceof Error ? error.message : String(error);
  return message
    .replace(/-----BEGIN PRIVATE KEY-----[\s\S]*?-----END PRIVATE KEY-----/gu, '[redacted]')
    .replace(/ya29\.[A-Za-z0-9._-]+/gu, '[redacted-token]');
}
