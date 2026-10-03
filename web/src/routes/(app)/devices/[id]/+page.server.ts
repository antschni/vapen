import { error, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { messageFromApiProblem } from '$lib/server/api-problem';
import {
	deviceNameSchema,
	ingestTokenNameSchema
} from '$lib/server/form-schemas';
import { de } from '$lib/i18n/de';
import { toIso } from '$lib/server/ranges';
import { TZDate } from '@date-fns/tz';
import { subDays, startOfDay } from 'date-fns';

export const load: PageServerLoad = async ({ locals, parent, params }) => {
	const { user } = await parent();
	const tz = user.timezone;
	const now = new TZDate(new Date(), tz);
	const from = startOfDay(subDays(now, 6));
	const to = now;

	const [deviceRes, tokensRes, statsRes] = await Promise.all([
		locals.api!.GET('/devices/{id}', { params: { path: { id: params.id } } }),
		locals.api!.GET('/devices/{id}/ingest-tokens', { params: { path: { id: params.id } } }),
		locals.api!.GET('/stats/devices/{id}', {
			params: { path: { id: params.id } },
			query: { from: toIso(from), to: toIso(to), bucket: 'day', tz }
		})
	]);

	if (deviceRes.error || !deviceRes.data) {
		error(deviceRes.response.status === 404 ? 404 : 500, de.errors.notFound);
	}

	return {
		device: deviceRes.data,
		tokens: tokensRes.data ?? [],
		stats: statsRes.data ?? null
	};
};

export const actions: Actions = {
	rename: async ({ request, locals, params }) => {
		const form = await request.formData();
		const parsed = deviceNameSchema.safeParse({ name: form.get('name') });
		if (!parsed.success) {
			return fail(400, { renameError: de.errors.validationFailed });
		}
		const { error: apiError, response } = await locals.api!.PATCH('/devices/{id}', {
			params: { path: { id: params.id } },
			body: parsed.data
		});
		if (apiError) {
			return fail(response.status, { renameError: messageFromApiProblem(apiError) });
		}
		return { renameSuccess: true };
	},
	delete: async ({ locals, params }) => {
		const { error: apiError, response } = await locals.api!.DELETE('/devices/{id}', {
			params: { path: { id: params.id } }
		});
		if (apiError) {
			return fail(response.status, { deleteError: messageFromApiProblem(apiError) });
		}
		redirect(303, '/devices');
	},
	createToken: async ({ request, locals, params }) => {
		const form = await request.formData();
		const parsed = ingestTokenNameSchema.safeParse({ name: form.get('name') });
		if (!parsed.success) {
			return fail(400, { tokenError: de.errors.validationFailed });
		}
		const { data, error: apiError, response } = await locals.api!.POST('/devices/{id}/ingest-tokens', {
			params: { path: { id: params.id } },
			body: parsed.data
		});
		if (apiError || !data) {
			return fail(response.status, { tokenError: messageFromApiProblem(apiError) });
		}
		return { newToken: data };
	},
	revokeToken: async ({ request, locals, params }) => {
		const tokenId = await formTokenId(await request.formData());
		if (!tokenId) return fail(400, { tokenError: de.errors.validationFailed });
		const { error: apiError, response } = await locals.api!.DELETE(
			'/devices/{id}/ingest-tokens/{token_id}',
			{ params: { path: { id: params.id, token_id: tokenId } } }
		);
		if (apiError) {
			return fail(response.status, { tokenError: messageFromApiProblem(apiError) });
		}
		return { revokeSuccess: true };
	}
};

async function formTokenId(form: FormData): Promise<string | null> {
	const id = form.get('token_id')?.toString();
	return id || null;
}
