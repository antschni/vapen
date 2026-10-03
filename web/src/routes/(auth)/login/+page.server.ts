import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { createPublicApiClient } from '$lib/server/api';
import { setTokenCookies } from '$lib/server/cookies';
import { getClientAddress } from '$lib/server/env';
import { validateRedirectTo } from '$lib/server/redirect';
import { loginSchema } from '$lib/server/auth-schemas';
import { messageFromApiProblem } from '$lib/server/api-problem';
import { de } from '$lib/i18n/de';

export const load: PageServerLoad = async ({ url }) => {
	return {
		redirectTo: validateRedirectTo(url.searchParams.get('redirectTo'))
	};
};

export const actions: Actions = {
	default: async (event) => {
		const form = await event.request.formData();
		const parsed = loginSchema.safeParse({
			email: form.get('email'),
			password: form.get('password')
		});

		if (!parsed.success) {
			return fail(400, {
				message: de.errors.validationFailed,
				fieldErrors: parsed.error.flatten().fieldErrors
			});
		}

		const api = createPublicApiClient(getClientAddress(event));
		const { data, error, response } = await api.POST('/auth/login', {
			body: parsed.data
		});

		if (error || !data) {
			return fail(response.status === 401 ? 401 : 400, {
				message: messageFromApiProblem(error, de.errors.invalidCredentials),
				fieldErrors: {}
			});
		}

		setTokenCookies(event.cookies, data);
		const target =
			validateRedirectTo(event.url.searchParams.get('redirectTo')) ??
			validateRedirectTo(form.get('redirectTo')?.toString()) ??
			'/';
		redirect(303, target);
	}
};
