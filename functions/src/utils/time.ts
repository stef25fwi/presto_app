export function nowMs(): number {
  return Date.now();
}

export function plusMinutes(baseMs: number, minutes: number): number {
  return baseMs + minutes * 60_000;
}
