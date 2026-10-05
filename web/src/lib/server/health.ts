/** Plain-text liveness body for Docker / Coolify probes. */
export function healthResponse(): Response {
  return new Response("ok", {
    status: 200,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}
