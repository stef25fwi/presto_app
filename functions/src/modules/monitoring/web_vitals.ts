import { createHash } from "node:crypto";

import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { PROJECT_REGION } from "../../config/env";
import { db } from "../../core/firestore";
import { logger } from "../../core/logger";
import {
  buildWebVitalsReport,
  classifyWebVital,
  DeviceCategory,
  normalizeWebVitalRoute,
  WebVitalMetric,
  WebVitalSample,
} from "./web_vitals_core";

const SAMPLE_COLLECTION = "web_vitals_samples";
const REPORT_COLLECTION = "web_vitals_reports";
const ALLOWED_METRICS = new Set<WebVitalMetric>(["LCP", "INP", "CLS"]);
const ALLOWED_DEVICES = new Set<DeviceCategory>(["mobile", "desktop"]);
const ALLOWED_HOSTS = new Set([
  "ilipresto.fr",
  "www.ilipresto.fr",
  "ilipresto.web.app",
  "ilipresto.firebaseapp.com",
  "presto-app-74abe.web.app",
  "presto-app-74abe.firebaseapp.com",
]);
const MAX_VALUES: Readonly<Record<WebVitalMetric, number>> = {
  LCP: 120_000,
  INP: 60_000,
  CLS: 10,
};
const SAMPLE_RETENTION_MS = 35 * 24 * 60 * 60 * 1000;
const REPORT_WINDOW_MS = 28 * 24 * 60 * 60 * 1000;
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX = 90;
const memoryRateLimits = new Map<string, { count: number; resetAt: number }>();

interface WebVitalPayload {
  schemaVersion?: unknown;
  metric?: unknown;
  value?: unknown;
  delta?: unknown;
  rating?: unknown;
  route?: unknown;
  deviceCategory?: unknown;
  navigationType?: unknown;
  releaseSha?: unknown;
  pageViewId?: unknown;
  collectedAtClient?: unknown;
}

function boundedString(value: unknown, maximum: number): string {
  return String(value ?? "").replace(/\s+/g, " ").trim().slice(0, maximum);
}

function requestFingerprint(ip: string): string {
  const day = new Date().toISOString().slice(0, 10);
  return createHash("sha256").update(`web-vitals:${day}:${ip}`).digest("hex").slice(0, 24);
}

function isRateLimited(fingerprint: string): boolean {
  const now = Date.now();
  const current = memoryRateLimits.get(fingerprint);
  if (!current || current.resetAt <= now) {
    memoryRateLimits.set(fingerprint, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return false;
  }
  current.count += 1;
  return current.count > RATE_LIMIT_MAX;
}

function isAllowedOrigin(originHeader: string): boolean {
  if (!originHeader) return false;
  try {
    return ALLOWED_HOSTS.has(new URL(originHeader).hostname.toLowerCase());
  } catch {
    return false;
  }
}

function parsePayload(body: unknown): WebVitalPayload | null {
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  return body as WebVitalPayload;
}

function normalizeMetric(value: unknown): WebVitalMetric | null {
  const metric = boundedString(value, 8).toUpperCase() as WebVitalMetric;
  return ALLOWED_METRICS.has(metric) ? metric : null;
}

function normalizeDevice(value: unknown): DeviceCategory | null {
  const device = boundedString(value, 16).toLowerCase() as DeviceCategory;
  return ALLOWED_DEVICES.has(device) ? device : null;
}

function normalizeFiniteNumber(value: unknown): number | null {
  const numeric = typeof value === "number" ? value : Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

export const collectWebVitals = onRequest(
  {
    region: PROJECT_REGION,
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 10,
    cors: true,
  },
  async (req, res) => {
    res.set("Cache-Control", "no-store");
    res.set("X-Content-Type-Options", "nosniff");

    if (req.method !== "POST") {
      res.status(405).set("Allow", "POST").json({ ok: false, error: "method_not_allowed" });
      return;
    }

    if (req.get("DNT") === "1" || req.get("Sec-GPC") === "1") {
      res.status(204).send("");
      return;
    }

    if (!isAllowedOrigin(req.get("origin") ?? "")) {
      res.status(403).json({ ok: false, error: "origin_not_allowed" });
      return;
    }

    const contentLength = Number(req.get("content-length") ?? "0");
    if (Number.isFinite(contentLength) && contentLength > 8192) {
      res.status(413).json({ ok: false, error: "payload_too_large" });
      return;
    }

    const fingerprint = requestFingerprint(req.ip || "unknown");
    if (isRateLimited(fingerprint)) {
      res.status(429).json({ ok: false, error: "rate_limited" });
      return;
    }

    const payload = parsePayload(req.body);
    const metric = normalizeMetric(payload?.metric);
    const deviceCategory = normalizeDevice(payload?.deviceCategory);
    const value = normalizeFiniteNumber(payload?.value);
    const pageViewId = boundedString(payload?.pageViewId, 80);

    if (
      payload?.schemaVersion !== 1 ||
      metric === null ||
      deviceCategory === null ||
      value === null ||
      value < 0 ||
      value > MAX_VALUES[metric] ||
      !/^[A-Za-z0-9_-]{12,80}$/.test(pageViewId)
    ) {
      res.status(400).json({ ok: false, error: "invalid_metric" });
      return;
    }

    const now = Date.now();
    const route = normalizeWebVitalRoute(payload?.route);
    const documentId = createHash("sha256")
      .update(`${pageViewId}:${metric}`)
      .digest("hex");

    await db.collection(SAMPLE_COLLECTION).doc(documentId).set({
      schemaVersion: 1,
      metric,
      value,
      delta: normalizeFiniteNumber(payload?.delta),
      rating: classifyWebVital(metric, value),
      route,
      deviceCategory,
      navigationType: boundedString(payload?.navigationType, 32) || "unknown",
      releaseSha: boundedString(payload?.releaseSha, 64) || "unknown",
      collectedAtClient: boundedString(payload?.collectedAtClient, 40) || null,
      collectedAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(now + SAMPLE_RETENTION_MS),
      source: "self_hosted_rum",
      anonymous: true,
    }, { merge: true });

    res.status(202).json({ ok: true });
  },
);

export const aggregateWebVitals28Days = onSchedule(
  {
    schedule: "every day 05:10",
    region: PROJECT_REGION,
    timeZone: "Europe/Paris",
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async () => {
    const generatedAt = Date.now();
    const windowStart = generatedAt - REPORT_WINDOW_MS;
    const snapshot = await db
      .collection(SAMPLE_COLLECTION)
      .where("collectedAt", ">=", Timestamp.fromMillis(windowStart))
      .limit(50_000)
      .get();

    const samples: WebVitalSample[] = [];
    const routeCounts: Record<string, number> = {};
    for (const document of snapshot.docs) {
      const data = document.data();
      const metric = normalizeMetric(data.metric);
      const deviceCategory = normalizeDevice(data.deviceCategory);
      const value = normalizeFiniteNumber(data.value);
      if (metric === null || deviceCategory === null || value === null) continue;
      const route = normalizeWebVitalRoute(data.route);
      samples.push({ metric, deviceCategory, value, route });
      routeCounts[route] = (routeCounts[route] ?? 0) + 1;
    }

    const report = buildWebVitalsReport(samples, {
      windowDays: 28,
      minimumSamplesPerMetric: 75,
    });
    const evidence = {
      ...report,
      generatedAt,
      windowStart,
      windowEnd: generatedAt,
      sourceCollection: SAMPLE_COLLECTION,
      releaseShas: Array.from(new Set(snapshot.docs.map((doc) => boundedString(doc.data().releaseSha, 64))))
        .filter(Boolean)
        .slice(0, 20),
      topRoutes: Object.entries(routeCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 25)
        .map(([route, sampleCount]) => ({ route, sampleCount })),
    };
    const dateKey = new Date(generatedAt).toISOString().slice(0, 10);

    await Promise.all([
      db.collection(REPORT_COLLECTION).doc("latest").set(evidence),
      db.collection(REPORT_COLLECTION).doc(dateKey).set(evidence),
    ]);

    logger.info("web_vitals_28_day_report", {
      status: report.status,
      totalSamples: report.totalSamples,
      mobileStatus: report.devices.mobile.status,
      desktopStatus: report.devices.desktop.status,
    });
  },
);

export const purgeExpiredWebVitals = onSchedule(
  {
    schedule: "every day 05:40",
    region: PROJECT_REGION,
    timeZone: "Europe/Paris",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    let deleted = 0;
    for (let iteration = 0; iteration < 10; iteration += 1) {
      const snapshot = await db
        .collection(SAMPLE_COLLECTION)
        .where("expiresAt", "<", Timestamp.now())
        .limit(500)
        .get();
      if (snapshot.empty) break;
      const batch = db.batch();
      for (const document of snapshot.docs) batch.delete(document.ref);
      await batch.commit();
      deleted += snapshot.size;
      if (snapshot.size < 500) break;
    }
    logger.info("web_vitals_samples_purged", { deleted });
  },
);
