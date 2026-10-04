import type { Cookies } from "@sveltejs/kit";
import type { components } from "#lib/api/schema.d.ts";
import {
  getAccessTokenFromCookieStore,
  getRefreshTokenFromCookieStore,
  setTokenCookies,
  clearTokenCookies,
} from "#lib/server/cookies.js";
import { accessTokenExpiresWithinSeconds } from "#lib/server/jwt.js";
import { createPublicApiClient } from "#lib/server/api.js";
import { mapProblemCodeToGerman } from "#lib/server/problems.js";

type TokenPair = components["schemas"]["TokenPair"];

const REFRESH_THRESHOLD_SECONDS = 60;

const refreshInflight = new Map<string, Promise<TokenPair>>();

export function getRefreshInflightMap(): Map<string, Promise<TokenPair>> {
  return refreshInflight;
}

export async function refreshTokens(
  refreshToken: string,
  forwardedFor?: string,
): Promise<TokenPair> {
  const existing = refreshInflight.get(refreshToken);
  if (existing) return existing;

  const promise = (async () => {
    const api = createPublicApiClient(forwardedFor);
    const { data, error, response } = await api.POST("/auth/refresh", {
      body: { refresh_token: refreshToken },
    });
    if (error || !data) {
      const code = (error as { code?: string } | undefined)?.code;
      const message = mapProblemCodeToGerman(code, response.statusText);
      throw new SessionError(message, response.status);
    }
    return data;
  })();

  refreshInflight.set(refreshToken, promise);
  try {
    return await promise;
  } finally {
    refreshInflight.delete(refreshToken);
  }
}

export class SessionError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "SessionError";
  }
}

export type SessionResult =
  | { ok: true; accessToken: string; refreshed: boolean }
  | { ok: false; reason: "missing" | "refresh_failed" };

/**
 * Returns a valid access token, refreshing cookies when exp is within 60s.
 */
export async function getAccessTokenFromCookies(
  cookies: Cookies,
  forwardedFor?: string,
): Promise<SessionResult> {
  const accessToken = getAccessTokenFromCookieStore(cookies);
  const refreshToken = getRefreshTokenFromCookieStore(cookies);

  if (!accessToken && !refreshToken) {
    return { ok: false, reason: "missing" };
  }

  if (
    accessToken &&
    !accessTokenExpiresWithinSeconds(accessToken, REFRESH_THRESHOLD_SECONDS)
  ) {
    return { ok: true, accessToken, refreshed: false };
  }

  if (!refreshToken) {
    clearTokenCookies(cookies);
    return { ok: false, reason: "refresh_failed" };
  }

  try {
    const pair = await refreshTokens(refreshToken, forwardedFor);
    setTokenCookies(cookies, pair);
    return { ok: true, accessToken: pair.access_token, refreshed: true };
  } catch {
    clearTokenCookies(cookies);
    return { ok: false, reason: "refresh_failed" };
  }
}
