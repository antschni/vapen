import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { privacyDefaultsSchema } from '$lib/server/form-schemas';
import { messageFromApiProblem } from '$lib/server/api-problem';
import { PRIVACY_FLAGS, overrideFromForm } from '$lib/privacy';
import { de } from '$lib/i18n/de';

export const load: PageServerLoad = async ({ locals, parent }) => {
	const { groups } = await parent();
	const defaultsRes = await locals.api!.GET('/me/privacy-defaults');
	const groupPrivacy = await Promise.all(
		groups.map(async (g) => {
			const res = await locals.api!.GET('/groups/{id}/privacy', {
				params: { path: { id: g.id } }
			});
			return { groupId: g.id, groupName: g.name, privacy: res.data ?? null };
		})
	);

	return {
		defaults: defaultsRes.data ?? null,
		groupPrivacy
	};
};

export const actions: Actions = {
	defaults: async ({ request, locals }) => {
		const form = await request.formData();
		const body = {
			share_live_status: form.has('share_live_status'),
			share_usage_summary: form.has('share_usage_summary'),
			share_usage_detail: form.has('share_usage_detail'),
			share_device_stats: form.has('share_device_stats'),
			show_in_leaderboard: form.has('show_in_leaderboard')
		};
		const parsed = privacyDefaultsSchema.safeParse(body);
		if (!parsed.success) return fail(400, { message: de.errors.validationFailed });
		const { error, response } = await locals.api!.PUT('/me/privacy-defaults', { body: parsed.data });
		if (error) return fail(response.status, { message: messageFromApiProblem(error) });
		return { saved: true };
	},
	group: async ({ request, locals }) => {
		const form = await request.formData();
		const groupId = form.get('group_id')?.toString();
		if (!groupId) return fail(400, { message: de.errors.validationFailed });
		const overrides: Record<string, boolean | null> = {};
		for (const flag of PRIVACY_FLAGS) {
			const raw = form.get(flag)?.toString() ?? 'inherit';
			overrides[flag] = overrideFromForm(raw);
		}
		const { error, response } = await locals.api!.PUT('/groups/{id}/privacy', {
			params: { path: { id: groupId } },
			body: { overrides }
		});
		if (error) return fail(response.status, { message: messageFromApiProblem(error) });
		return { saved: true };
	}
};
