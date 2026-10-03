import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { rangeFromPreset, toIso, type RangePreset } from '$lib/server/ranges';
import { de } from '$lib/i18n/de';

const RANGES: RangePreset[] = ['today', '7d', '30d'];

export const load: PageServerLoad = async ({ locals, parent, params, url }) => {
	const { user, groups } = await parent();
	const membership = groups.find((g) => g.id === params.id);
	if (!membership) {
		error(404, de.errors.notFound);
	}

	const rangeRaw = url.searchParams.get('range') ?? '7d';
	const range = RANGES.includes(rangeRaw as RangePreset) ? (rangeRaw as RangePreset) : '7d';
	const tz = user.timezone;
	const { from, to } = rangeFromPreset(range, tz);

	const overview = await locals.api!.GET('/groups/{id}/overview', {
		params: { path: { id: params.id } },
		query: { from: toIso(from), to: toIso(to), tz }
	});

	if (overview.error || !overview.data) {
		error(overview.response.status === 404 ? 404 : 500, de.errors.generic);
	}

	return {
		groupId: params.id,
		groupName: overview.data.group.name,
		role: membership.role,
		range,
		overview: overview.data
	};
};
