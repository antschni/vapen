import { fail } from "@sveltejs/kit";
import type { Actions, PageServerLoad } from "./$types";
import { messageFromApiProblem } from "#lib/server/api-problem.js";
import { parseUsageFilters } from "#lib/server/usage-params.js";
import { de } from "#lib/i18n/de.js";

const PUFF_LIMIT = 50;
const HTTP_BAD_REQUEST = 400;

function parseDurationField(value: FormDataEntryValue | null): number | undefined {
  if (typeof value !== "string" || value === "") return undefined;
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? n : undefined;
}

export const load: PageServerLoad = async ({ locals, parent, url }) => {
  const { user, groups } = await parent();
  const tz = user.timezone;
  const filters = parseUsageFilters(url, tz, user.id);

  const statsQuery = {
    from: filters.fromIso,
    to: filters.toIso,
    bucket: filters.bucket,
    tz,
    ...(filters.deviceId ? { device_id: filters.deviceId } : {}),
    ...(filters.userId ? { user_id: filters.userId } : {}),
  };

  const [statsRes, devicesRes, puffsRes, ...overviewResults] =
    await Promise.all([
      locals.api!.GET("/stats/usage", { query: statsQuery }),
      locals.api!.GET("/devices"),
      locals.api!.GET("/puffs", {
        query: {
          from: filters.fromIso,
          to: filters.toIso,
          order: "desc",
          limit: PUFF_LIMIT,
          ...(filters.deviceId ? { device_id: filters.deviceId } : {}),
          ...(filters.userId ? { user_id: filters.userId } : {}),
          ...(filters.minDurationMs
            ? { min_duration_ms: filters.minDurationMs }
            : {}),
          ...(filters.maxDurationMs
            ? { max_duration_ms: filters.maxDurationMs }
            : {}),
        },
      }),
      ...groups.map((g) =>
        locals.api!.GET("/groups/{id}/overview", {
          params: { path: { id: g.id } },
          query: { tz, from: filters.fromIso, to: filters.toIso },
        }),
      ),
    ]);

  const detailMembers = new Map<string, string>(
    overviewResults
      .flatMap((res) => res.data?.members ?? [])
      .filter((m) => m.visibility.usage_detail && m.user_id !== user.id)
      .map((m) => [m.user_id, m.display_name]),
  );

  const series =
    statsRes.data?.series.map((s) => ({
      label: s.bucket_start,
      durationMs: s.total_duration_ms,
      puffCount: s.puff_count,
    })) ?? [];

  return {
    filters,
    stats: statsRes.data ?? null,
    series,
    heatmap: statsRes.data?.heatmap ?? [],
    devices: devicesRes.data ?? [],
    puffs: puffsRes.data?.items ?? [],
    puffNextCursor: puffsRes.data?.next_cursor ?? null,
    detailMembers: [...detailMembers.entries()].map(([id, name]) => ({
      id,
      name,
    })),
  };
};

export const actions: Actions = {
  loadMore: async ({ request, locals }) => {
    const user = locals.user!;
    const form = await request.formData();
    const cursor = form.get("cursor")?.toString();
    if (!cursor) {
      return fail(HTTP_BAD_REQUEST, { message: "missing cursor" });
    }

    const from = form.get("from")?.toString();
    const to = form.get("to")?.toString();
    const deviceId = form.get("device_id")?.toString();
    const userId = form.get("user_id")?.toString();
    const minDurationMs = parseDurationField(form.get("min_duration_ms"));
    const maxDurationMs = parseDurationField(form.get("max_duration_ms"));

    const { data, error } = await locals.api!.GET("/puffs", {
      query: {
        from,
        to,
        order: "desc",
        limit: PUFF_LIMIT,
        cursor,
        ...(deviceId ? { device_id: deviceId } : {}),
        ...(userId && userId !== user.id ? { user_id: userId } : {}),
        ...(minDurationMs !== undefined
          ? { min_duration_ms: minDurationMs }
          : {}),
        ...(maxDurationMs !== undefined
          ? { max_duration_ms: maxDurationMs }
          : {}),
      },
    });

    if (error || !data) {
      return fail(HTTP_BAD_REQUEST, { message: messageFromApiProblem(error, de.errors.generic) });
    }

    return {
      items: data.items,
      next_cursor: data.next_cursor,
    };
  },
};
