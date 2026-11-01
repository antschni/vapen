import type { RequestHandler } from "./$types";
import { error } from "@sveltejs/kit";
import { getClientAddress, getServerEnv } from "#lib/server/env.js";
import { getAccessTokenFromCookies } from "#lib/server/session.js";

const HTTP_OK = 200;
const HTTP_UNAUTHORIZED = 401;
const HTTP_NOT_FOUND = 404;
const HTTP_BAD_GATEWAY = 502;
const HTTP_ERROR_MIN = 400;
const HTTP_ERROR_MAX = 599;

// Canonical UUID, case-insensitive.
// Matches "3f2a9c1e-0b4d-4e6f-8a7b-1c2d3e4f5a6b"; rejects "../../me/export?x=".
// https://regex101.com/?flavor=javascript&flags=i&regex=%5E%5B0-9a-f%5D%7B8%7D-%5B0-9a-f%5D%7B4%7D-%5B0-9a-f%5D%7B4%7D-%5B0-9a-f%5D%7B4%7D-%5B0-9a-f%5D%7B12%7D%24&testString=3f2a9c1e-0b4d-4e6f-8a7b-1c2d3e4f5a6b%0A..%2F..%2Fme%2Fexport%3Fx%3D
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function apiBase(url: string): string {
  return url.endsWith("/") ? url.slice(0, -1) : url;
}

export const GET: RequestHandler = async (event) => {
  const { params, cookies } = event;
  // Params are URI-decoded; reject anything that is not a plain UUID so
  // `..%2F` segments cannot redirect the proxy to other API routes.
  if (!UUID_RE.test(params.id)) {
    error(HTTP_NOT_FOUND, "Not found");
  }

  const forwardedFor = getClientAddress(event);
  const session = await getAccessTokenFromCookies(cookies, forwardedFor);
  if (!session.ok) {
    error(HTTP_UNAUTHORIZED, "Unauthorized");
  }

  const { apiInternalUrl } = getServerEnv();
  const headers: Record<string, string> = {
    Authorization: `Bearer ${session.accessToken}`,
    Accept: "text/event-stream",
  };
  if (forwardedFor) {
    headers["X-Forwarded-For"] = forwardedFor;
  }
  const upstream = await fetch(
    `${apiBase(apiInternalUrl)}/api/v1/groups/${encodeURIComponent(params.id)}/live`,
    { headers, redirect: "manual" },
  );

  if (!upstream.ok) {
    // error() only accepts 4xx/5xx; map anything else to a gateway error.
    const status =
      upstream.status >= HTTP_ERROR_MIN && upstream.status <= HTTP_ERROR_MAX
        ? upstream.status
        : HTTP_BAD_GATEWAY;
    error(status, upstream.statusText || "Upstream error");
  }

  if (!upstream.body) {
    error(HTTP_BAD_GATEWAY, "No stream body");
  }

  return new Response(upstream.body, {
    status: HTTP_OK,
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "X-Accel-Buffering": "no",
      Connection: "keep-alive",
    },
  });
};
