import { TZDate } from '@date-fns/tz';
import { format, startOfDay, subDays } from 'date-fns';
import { de as dateFnsDe } from 'date-fns/locale';
import type { PageServerLoad } from './$types';
import { toIso } from '$lib/server/ranges';

export const load: PageServerLoad = async ({ locals, parent }) => {
	const { user, groups } = await parent();
	const tz = user.timezone;
	const now = new TZDate(new Date(), tz);
	const todayStart = startOfDay(now);
	const yesterdayStart = startOfDay(subDays(now, 1));
	const yesterdayEnd = todayStart;

	const [todayStats, yesterdayStats, weekStats, devicesRes] = await Promise.all([
		locals.api!.GET('/stats/usage', {
			query: {
				from: toIso(todayStart),
				to: toIso(now),
				bucket: 'hour',
				tz
			}
		}),
		locals.api!.GET('/stats/usage', {
			query: {
				from: toIso(yesterdayStart),
				to: toIso(yesterdayEnd),
				bucket: 'day',
				tz
			}
		}),
		locals.api!.GET('/stats/usage', {
			query: {
				from: toIso(startOfDay(subDays(now, 6))),
				to: toIso(now),
				bucket: 'day',
				tz
			}
		}),
		locals.api!.GET('/devices')
	]);

	const devices = devicesRes.data ?? [];
	const primaryDevice = devices[0];

	let groupOverview = null;
	const firstGroup = groups[0];
	if (firstGroup) {
		const overview = await locals.api!.GET('/groups/{id}/overview', {
			params: { path: { id: firstGroup.id } },
			query: { tz }
		});
		groupOverview = overview.data ?? null;
	}

	const today = todayStats.data;
	const yesterday = yesterdayStats.data;
	const week = weekStats.data;

	const barPoints =
		week?.series.map((s) => ({
			label: format(new Date(s.bucket_start), 'EEE', { locale: dateFnsDe }),
			durationMs: s.total_duration_ms,
			puffCount: s.puff_count
		})) ?? [];

	const hourlyToday =
		today?.series.map((s) => ({
			label: format(new Date(s.bucket_start), 'HH', { locale: dateFnsDe }),
			durationMs: s.total_duration_ms,
			puffCount: s.puff_count
		})) ?? [];

	const puffDelta =
		today && yesterday
			? today.totals.puff_count - yesterday.totals.puff_count
			: null;
	const durationDelta =
		today && yesterday
			? today.totals.total_duration_ms - yesterday.totals.total_duration_ms
			: null;

	const avg7 =
		week && week.series.length > 0
			? Math.round(week.totals.puff_count / Math.max(week.totals.active_days, 1))
			: 0;

	return {
		todayTotals: today?.totals ?? null,
		puffDelta,
		durationDelta,
		avg7,
		lastPuffAt: today?.series.at(-1)?.bucket_start ?? null,
		battery: primaryDevice?.latest_status?.battery_percent ?? null,
		isCharging: primaryDevice?.latest_status?.is_charging ?? false,
		barPoints,
		hourlyToday,
		firstGroupId: firstGroup?.id ?? null,
		groupOverview
	};
};
