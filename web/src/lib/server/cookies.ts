import type { Cookies } from "@sveltejs/kit";
import type { components } from "#lib/api/schema.d.ts";
import { getServerEnv } from "#lib/server/env.js";

export const ACCESS_COOKIE = "vapen_at";
export const REFRESH_COOKIE = "vapen_rt";

type TokenPair = components["schemas"]["TokenPair"];

function cookieOptions(maxAgeSeconds: number, path = "/") {
  const { cookieSecure } = getServerEnv();
  return {
    path,
    httpOnly: true,
    secure: cookieSecure,
    sameSite: "lax" as const,
    maxAge: maxAgeSeconds,
  };
}

function maxAgeFromExpiresAt(iso: string): number {
  const expMs = Date.parse(iso);
  const now = Date.now();
  return Math.max(0, Math.floor((expMs - now) / 1000));
}

export function setTokenCookies(cookies: Cookies, pair: TokenPair): void {
  cookies.set(
    ACCESS_COOKIE,
    pair.access_token,
    cookieOptions(maxAgeFromExpiresAt(pair.access_token_expires_at)),
  );
  cookies.set(
    REFRESH_COOKIE,
    pair.refresh_token,
    cookieOptions(maxAgeFromExpiresAt(pair.refresh_token_expires_at), "/"),
  );
}

export function clearTokenCookies(cookies: Cookies): void {
  cookies.delete(ACCESS_COOKIE, { path: "/" });
  cookies.delete(REFRESH_COOKIE, { path: "/" });
}

export function getAccessTokenFromCookieStore(
  cookies: Cookies,
): string | undefined {
  return cookies.get(ACCESS_COOKIE);
}

export function getRefreshTokenFromCookieStore(
  cookies: Cookies,
): string | undefined {
  return cookies.get(REFRESH_COOKIE);
}
