import type { Handle } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';
import { createApiClient } from '$lib/server/api';
import { getClientAddress } from '$lib/server/env';
import { clearTokenCookies } from '$lib/server/cookies';
import { getAccessTokenFromCookies } from '$lib/server/session';
import { validateRedirectTo } from '$lib/server/redirect';
import type { components } from '$lib/api/schema.d.ts';

type User = Pick<
	components['schemas']['User'],
	'id' | 'email' | 'display_name' | 'timezone'
>;

function isProtectedRoute(routeId: string | null): boolean {
	return routeId?.startsWith('/(app)') ?? false;
}

function isAuthRoute(routeId: string | null): boolean {
	return routeId?.startsWith('/(auth)') ?? false;
}

const securityHeaders: Record<string, string> = {
	'Referrer-Policy': 'strict-origin-when-cross-origin',
	'X-Content-Type-Options': 'nosniff',
	'Permissions-Policy': 'camera=(), microphone=(), geolocation=()'
};

export const handle: Handle = async ({ event, resolve }) => {
	const forwardedFor = getClientAddress(event);
	const session = await getAccessTokenFromCookies(event.cookies, forwardedFor);

	if (session.ok) {
		const api = createApiClient(session.accessToken, forwardedFor);
		const { data, error, response } = await api.GET('/me');
		if (data && !error) {
			const user: User = {
				id: data.id,
				email: data.email,
				display_name: data.display_name,
				timezone: data.timezone
			};
			event.locals.user = user;
			event.locals.api = api;
		} else if (response.status === 401) {
			clearTokenCookies(event.cookies);
		} else {
			event.locals.api = api;
		}
	}

	const routeId = event.route.id;
	const protectedRoute = isProtectedRoute(routeId);

	if (protectedRoute && !event.locals.user) {
		const redirectTo = validateRedirectTo(event.url.pathname + event.url.search) ?? '/';
		redirect(303, `/login?redirectTo=${encodeURIComponent(redirectTo)}`);
	}

	if (isAuthRoute(routeId) && event.locals.user) {
		const target = validateRedirectTo(event.url.searchParams.get('redirectTo')) ?? '/';
		redirect(303, target);
	}

	const response = await resolve(event);

	for (const [key, value] of Object.entries(securityHeaders)) {
		response.headers.set(key, value);
	}

	return response;
};
