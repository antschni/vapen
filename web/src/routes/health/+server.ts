import type { RequestHandler } from "@sveltejs/kit";

/** Liveness probe for Docker / Coolify (no API or auth). */
export const GET: RequestHandler = () => {
  return new Response("ok", {
    status: 200,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
};
