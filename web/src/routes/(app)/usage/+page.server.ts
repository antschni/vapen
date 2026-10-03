import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { parseUsageFilters } from '$lib/server/usage-params';
const PUFF_LIMIT = 50;

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
		...(filters.userId ? { user_id: filters.userId } : {})
	};

	const [statsRes, devicesRes, puffsRes, ...overviewResults] = await Promise.all([
		locals.api!.GET('/stats/usage', { query: statsQuery }),
		locals.api!.GET('/devices'),
		locals.api!.GET('/puffs', {
			query: {
				from: filters.fromIso,
				to: filters.toIso,
				order: 'desc',
				limit: PUFF_LIMIT,
				...(filters.deviceId ? { device_id: filters.deviceId } : {}),
				...(filters.userId ? { user_id: filters.userId } : {}),
				...(filters.minDurationMs ? { min_duration_ms: filters.minDurationMs } : {}),
				...(filters.maxDurationMs ? { max_duration_ms: filters.maxDurationMs } : {})
			}
		}),
		...groups.map((g) =>
			locals.api!.GET('/groups/{id}/overview', {
				params: { path: { id: g.id } },
				query: { tz, from: filters.fromIso, to: filters.toIso }
			})
		)
	]);

	const detailMembers = new Map<string, string>();
	for (const res of overviewResults) {
		for (const m of res.data?.members ?? []) {
			if (m.visibility.usage_detail && m.user_id !== user.id) {
				detailMembers.set(m.user_id, m.display_name);
			}
		}
	}

	const series =
		statsRes.data?.series.map((s) => ({
			label: s.bucket_start,
			durationMs: s.total_duration_ms,
			puffCount: s.puff_count
		})) ?? [];

	return {
		filters,
		stats: statsRes.data ?? null,
		series,
		heatmap: statsRes.data?.heatmap ?? [],
		devices: devicesRes.data ?? [],
		puffs: puffsRes.data?.items ?? [],
		puffNextCursor: puffsRes.data?.next_cursor ?? null,
		detailMembers: [...detailMembers.entries()].map(([id, name]) => ({ id, name }))
	};
};

export const actions: Actions = {
	loadMore: async ({ request, locals }) => {
		const user = locals.user!;
		const form = await request.formData();
		const cursor = form.get('cursor')?.toString();
		if (!cursor) {
			return fail(400, { message: 'missing cursor' });
		}

		const from = form.get('from')?.toString();
		const to = form.get('to')?.toString();
		const deviceId = form.get('device_id')?.toString();
		const userId = form.get('user_id')?.toString();

		const { data, error } = await locals.api!.GET('/puffs', {
			query: {
				from,
				to,
				order: 'desc',
				limit: PUFF_LIMIT,
				cursor,
				...(deviceId ? { device_id: deviceId } : {}),
				...(userId && userId !== user.id ? { user_id: userId } : {})
			}
		});

		if (error || !data) {
			return fail(500, { message: 'load failed' });
		}

		return {
			items: data.items,
			next_cursor: data.next_cursor
		};
	}
};
