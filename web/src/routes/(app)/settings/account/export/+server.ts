import { error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals }) => {
	if (!locals.api) error(401, 'Unauthorized');
	const { data, error: apiError, response } = await locals.api.GET('/me/export');
	if (apiError || !data) error(response.status, 'Export failed');
	const body = JSON.stringify(data, null, 2);
	return new Response(body, {
		headers: {
			'Content-Type': 'application/json; charset=utf-8',
			'Content-Disposition': 'attachment; filename="vapen-export.json"'
		}
	});
};
