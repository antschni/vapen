import {
  API_INTERNAL_URL,
  ORIGIN,
  COOKIE_SECURE,
  PROTOCOL_HEADER,
  HOST_HEADER,
  ADDRESS_HEADER,
  XFF_DEPTH,
  ANDROID_PACKAGE_NAME,
  ANDROID_CERT_SHA256_FINGERPRINTS,
} from "$app/env/private";

import type { RequestEvent } from "@sveltejs/kit";

function parseBool(value: string | undefined, defaultValue: boolean): boolean {
  if (value === undefined || value === "") return defaultValue;
  return value === "true" || value === "1";
}

function parseIntEnv(value: string | undefined, defaultValue: number): number {
  if (value === undefined || value === "") return defaultValue;
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? n : defaultValue;
}

export function getServerEnv() {
  return {
    apiInternalUrl: API_INTERNAL_URL || "http://localhost:8080",
    origin: ORIGIN || "http://localhost:5173",
    // Default to Secure cookies whenever the public origin is HTTPS.
    cookieSecure: parseBool(
      COOKIE_SECURE || undefined,
      (ORIGIN || "").startsWith("https://"),
    ),
    protocolHeader: PROTOCOL_HEADER || "x-forwarded-proto",
    hostHeader: HOST_HEADER || "x-forwarded-host",
    // Only trust a forwarding header when one is configured explicitly;
    // otherwise clients could spoof their IP to dodge login rate limits.
    addressHeader: ADDRESS_HEADER || undefined,
    xffDepth: parseIntEnv(XFF_DEPTH || undefined, 1),
    androidPackageName: ANDROID_PACKAGE_NAME || "dev.vapen.app",
    androidCertSha256Fingerprints: (ANDROID_CERT_SHA256_FINGERPRINTS || "")
      .split(",")
      .map((s: string) => s.trim())
      .filter(Boolean),
  };
}

/** Client IP for API rate limiting (login), forwarded as X-Forwarded-For. */
export function getClientAddress(event: RequestEvent): string | undefined {
  const { addressHeader, xffDepth } = getServerEnv();
  if (!addressHeader) {
    return event.getClientAddress();
  }
  const raw = event.request.headers.get(addressHeader);
  if (!raw) {
    return event.getClientAddress();
  }
  const parts = raw
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean);
  if (parts.length === 0) {
    return event.getClientAddress();
  }
  const index = Math.max(0, parts.length - xffDepth);
  return parts[index] ?? parts[parts.length - 1];
}
