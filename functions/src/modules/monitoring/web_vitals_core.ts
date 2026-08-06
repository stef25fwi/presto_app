export type WebVitalMetric = "LCP" | "INP" | "CLS";
export type DeviceCategory = "mobile" | "desktop";
export type VitalRating = "good" | "needs-improvement" | "poor";

export interface WebVitalSample {
  metric: WebVitalMetric;
  value: number;
  deviceCategory: DeviceCategory;
  route: string;
}

export interface MetricSummary {
  metric: WebVitalMetric;
  threshold: number;
  sampleCount: number;
  p75: number | null;
  goodCount: number;
  goodRate: number | null;
  status: "pass" | "fail" | "insufficient-data";
}

export interface DeviceSummary {
  deviceCategory: DeviceCategory;
  sampleCount: number;
  metrics: Record<WebVitalMetric, MetricSummary>;
  status: "pass" | "fail" | "insufficient-data";
}

export interface WebVitalsReport {
  schemaVersion: 1;
  windowDays: number;
  minimumSamplesPerMetric: number;
  totalSamples: number;
  devices: Record<DeviceCategory, DeviceSummary>;
  status: "pass" | "fail" | "insufficient-data";
}

export const WEB_VITAL_THRESHOLDS: Readonly<Record<WebVitalMetric, number>> = {
  LCP: 2500,
  INP: 200,
  CLS: 0.1,
};

const METRICS: readonly WebVitalMetric[] = ["LCP", "INP", "CLS"];
const DEVICES: readonly DeviceCategory[] = ["mobile", "desktop"];

export function classifyWebVital(metric: WebVitalMetric, value: number): VitalRating {
  const good = WEB_VITAL_THRESHOLDS[metric];
  const poor = metric === "LCP" ? 4000 : metric === "INP" ? 500 : 0.25;
  if (value <= good) return "good";
  if (value <= poor) return "needs-improvement";
  return "poor";
}

export function percentile(values: readonly number[], quantile: number): number | null {
  if (values.length === 0) return null;
  const normalized = Math.min(1, Math.max(0, quantile));
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.max(0, Math.ceil(normalized * sorted.length) - 1);
  return sorted[index] ?? null;
}

export function normalizeWebVitalRoute(rawRoute: unknown): string {
  let route = String(rawRoute ?? "/").trim() || "/";
  route = route.split(/[?#]/, 1)[0] || "/";
  if (!route.startsWith("/")) route = `/${route}`;
  if (route.length > 1 && route.endsWith("/")) route = route.slice(0, -1);

  const segments = route.split("/").map((segment) => {
    if (!segment) return segment;
    const decoded = (() => {
      try {
        return decodeURIComponent(segment);
      } catch {
        return segment;
      }
    })();
    if (/^[0-9]{5,}$/.test(decoded)) return ":id";
    if (/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(decoded)) return ":id";
    if (/^[A-Za-z0-9_-]{24,}$/.test(decoded)) return ":id";
    return decoded.replace(/[^A-Za-z0-9À-ÖØ-öø-ÿ._~-]/g, "-").slice(0, 80);
  });

  return segments.join("/").slice(0, 180) || "/";
}

function summarizeMetric(
  metric: WebVitalMetric,
  samples: readonly WebVitalSample[],
  minimumSamples: number,
): MetricSummary {
  const values = samples.filter((sample) => sample.metric === metric).map((sample) => sample.value);
  const p75 = percentile(values, 0.75);
  const goodCount = values.filter((value) => value <= WEB_VITAL_THRESHOLDS[metric]).length;
  const goodRate = values.length === 0 ? null : goodCount / values.length;
  const status = values.length < minimumSamples
    ? "insufficient-data"
    : p75 !== null && p75 <= WEB_VITAL_THRESHOLDS[metric]
      ? "pass"
      : "fail";

  return {
    metric,
    threshold: WEB_VITAL_THRESHOLDS[metric],
    sampleCount: values.length,
    p75,
    goodCount,
    goodRate,
    status,
  };
}

function summarizeDevice(
  deviceCategory: DeviceCategory,
  samples: readonly WebVitalSample[],
  minimumSamples: number,
): DeviceSummary {
  const deviceSamples = samples.filter((sample) => sample.deviceCategory === deviceCategory);
  const metrics = Object.fromEntries(
    METRICS.map((metric) => [metric, summarizeMetric(metric, deviceSamples, minimumSamples)]),
  ) as Record<WebVitalMetric, MetricSummary>;
  const statuses = METRICS.map((metric) => metrics[metric].status);
  const status = statuses.includes("fail")
    ? "fail"
    : statuses.every((value) => value === "pass")
      ? "pass"
      : "insufficient-data";

  return {
    deviceCategory,
    sampleCount: deviceSamples.length,
    metrics,
    status,
  };
}

export function buildWebVitalsReport(
  samples: readonly WebVitalSample[],
  options: { windowDays?: number; minimumSamplesPerMetric?: number } = {},
): WebVitalsReport {
  const windowDays = options.windowDays ?? 28;
  const minimumSamplesPerMetric = options.minimumSamplesPerMetric ?? 75;
  const devices = Object.fromEntries(
    DEVICES.map((device) => [device, summarizeDevice(device, samples, minimumSamplesPerMetric)]),
  ) as Record<DeviceCategory, DeviceSummary>;
  const statuses = DEVICES.map((device) => devices[device].status);
  const status = statuses.includes("fail")
    ? "fail"
    : statuses.every((value) => value === "pass")
      ? "pass"
      : "insufficient-data";

  return {
    schemaVersion: 1,
    windowDays,
    minimumSamplesPerMetric,
    totalSamples: samples.length,
    devices,
    status,
  };
}
