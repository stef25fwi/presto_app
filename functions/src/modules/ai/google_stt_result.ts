interface SpeechResult {
  alternatives?: ReadonlyArray<{
    transcript?: string | null;
    confidence?: number | null;
  }> | null;
}

// Results are consecutive audio segments; alternatives are competing readings
// of the same segment. Keep the best reading of every segment in source order.
export function summarizeGoogleSttResults(
  results: ReadonlyArray<SpeechResult> | null | undefined,
): { text: string; googleConfidence: number | null } {
  const bestReadings = (results ?? [])
    .map((result) => result.alternatives?.[0])
    .filter((reading) => Boolean(reading?.transcript?.trim()));
  const scores = bestReadings
    .map((reading) => reading?.confidence)
    .filter((score): score is number =>
      typeof score === "number" && Number.isFinite(score) && score > 0 && score <= 1,
    );
  return {
    text: bestReadings.map((reading) => reading?.transcript?.trim()).join(" "),
    googleConfidence: scores.length
      ? scores.reduce((sum, score) => sum + score, 0) / scores.length
      : null,
  };
}
