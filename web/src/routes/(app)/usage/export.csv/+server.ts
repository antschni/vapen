import { error } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { parseUsageFilters } from "#lib/server/usage-params.js";
import { puffRowToCsv } from "#lib/server/csv.js";

const PAGE_SIZE = 200;
const MAX_ROWS = 10_000;

export const GET: RequestHandler = async ({ locals, url }) => {
  const user = locals.user;
  if (!user || !locals.api) error(401, "Unauthorized");
  const filters = parseUsageFilters(url, user.timezone, user.id);

  const lines = ["id,started_at,duration_ms,device_id,source"];
  let cursor: string | undefined;
  let total = 0;

  while (total < MAX_ROWS) {
    const { data, error: apiError } = await locals.api.GET("/puffs", {
      query: {
        from: filters.fromIso,
        to: filters.toIso,
        order: "desc",
        limit: PAGE_SIZE,
        ...(cursor ? { cursor } : {}),
        ...(filters.deviceId ? { device_id: filters.deviceId } : {}),
        ...(filters.userId ? { user_id: filters.userId } : {}),
        ...(filters.minDurationMs
          ? { min_duration_ms: filters.minDurationMs }
          : {}),
        ...(filters.maxDurationMs
          ? { max_duration_ms: filters.maxDurationMs }
          : {}),
      },
    });

    if (apiError || !data) error(502, "Export failed");

    for (const p of data.items) {
      lines.push(
        puffRowToCsv(p.id, p.started_at, p.duration_ms, p.device_id, p.source),
      );
      total += 1;
      if (total >= MAX_ROWS) break;
    }

    if (!data.next_cursor || data.items.length === 0) break;
    cursor = data.next_cursor;
  }

  return new Response(lines.join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="vapen-puffs.csv"',
    },
  });
};
