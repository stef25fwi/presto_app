export function average(values) {
  const valid = values.map(Number).filter(Number.isFinite);
  return valid.length ? valid.reduce((sum, value) => sum + value, 0) / valid.length : 0;
}

export function percentile(values, quantile) {
  const valid = values.map(Number).filter(Number.isFinite).sort((a, b) => a - b);
  if (!valid.length) return null;
  const index = Math.min(
    valid.length - 1,
    Math.max(0, Math.ceil(valid.length * Math.max(0, Math.min(1, quantile))) - 1),
  );
  return valid[index];
}

export function latencySummary(values) {
  return {
    average: Math.round(average(values)),
    p50: percentile(values, 0.5),
    p90: percentile(values, 0.9),
    p95: percentile(values, 0.95),
    p99: percentile(values, 0.99),
  };
}

export function groupBy(items, keyOf) {
  const groups = new Map();
  for (const item of items) {
    const key = keyOf(item);
    if (!key) continue;
    const bucket = groups.get(key);
    if (bucket) bucket.push(item);
    else groups.set(key, [item]);
  }
  return Object.fromEntries([...groups.entries()].sort(([a], [b]) => a.localeCompare(b)));
}

/**
 * Résume la qualité par groupe (accent, format, …) afin qu'une moyenne globale
 * acceptable ne masque pas une famille dégradée.
 */
export function qualitySummary(groups) {
  const summary = {};
  for (const [name, items] of Object.entries(groups)) {
    summary[name] = {
      cases: items.length,
      averageWer: Number(average(items.map((item) => item.wer)).toFixed(4)),
      averageEntityErrorRate: Number(
        average(items.map((item) => item.entityErrorRate)).toFixed(4),
      ),
      averageHallucinationExtraWordRate: Number(
        average(items.map((item) => item.hallucinationExtraWordRate)).toFixed(4),
      ),
      latencyMs: latencySummary(items.map((item) => item.latencyMs)),
      totalAudioSeconds: Number(
        items.reduce((sum, item) => sum + Number(item.audioSeconds || 0), 0).toFixed(3),
      ),
    };
  }
  return summary;
}

export function estimatedTranscriptionCostEur(audioSeconds) {
  const rate = Number(process.env.OPENAI_TRANSCRIPTION_EUR_PER_MINUTE || 0);
  if (!Number.isFinite(rate) || rate <= 0) return null;
  return Number(((Math.max(0, audioSeconds) / 60) * rate).toFixed(6));
}

export function estimatedVisionCostEur(inputTokens, outputTokens) {
  const inputRate = Number(process.env.OPENAI_INPUT_EUR_PER_MILLION_TOKENS || 0);
  const outputRate = Number(process.env.OPENAI_OUTPUT_EUR_PER_MILLION_TOKENS || 0);
  if ((!Number.isFinite(inputRate) || inputRate <= 0) && (!Number.isFinite(outputRate) || outputRate <= 0)) {
    return null;
  }
  return Number(
    (
      (Math.max(0, inputTokens) / 1_000_000) * Math.max(0, inputRate) +
      (Math.max(0, outputTokens) / 1_000_000) * Math.max(0, outputRate)
    ).toFixed(6),
  );
}
