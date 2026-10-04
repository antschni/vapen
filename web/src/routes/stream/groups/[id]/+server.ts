import type { RequestHandler } from "./$types";
import { error } from "@sveltejs/kit";
import { getClientAddress, getServerEnv } from "#lib/server/env.js";
import { getAccessTokenFromCookies } from "#lib/server/session.js";

export const GET: RequestHandler = async (event) => {
  const { params, cookies } = event;
  const forwardedFor = getClientAddress(event);
  const session = await getAccessTokenFromCookies(cookies, forwardedFor);
  if (!session.ok) {
    error(401, "Unauthorized");
  }

  const { apiInternalUrl } = getServerEnv();
  const upstream = await fetch(
    `${apiInternalUrl.replace(/\/$/, "")}/api/v1/groups/${params.id}/live`,
    {
      headers: {
        Authorization: `Bearer ${session.accessToken}`,
        Accept: "text/event-stream",
      },
    },
  );

  if (!upstream.ok) {
    error(upstream.status, upstream.statusText);
  }

  if (!upstream.body) {
    error(502, "No stream body");
  }

  return new Response(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "X-Accel-Buffering": "no",
      Connection: "keep-alive",
    },
  });
};
