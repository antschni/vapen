import createClient from 'openapi-fetch';
import type { paths } from '$lib/api/schema.d.ts';
import { getServerEnv } from '$lib/server/env';

export type ApiClient = ReturnType<typeof createApiClient>;

function apiBaseUrl(): string {
	const base = getServerEnv().apiInternalUrl.replace(/\/$/, '');
	return `${base}/api/v1`;
}

export function createApiClient(accessToken: string, forwardedFor?: string) {
	const headers: Record<string, string> = {
		Authorization: `Bearer ${accessToken}`
	};
	if (forwardedFor) {
		headers['X-Forwarded-For'] = forwardedFor;
	}
	return createClient<paths>({
		baseUrl: apiBaseUrl(),
		headers
	});
}

/** Unauthenticated client for register, login, refresh. */
export function createPublicApiClient(forwardedFor?: string) {
	const headers: Record<string, string> = {};
	if (forwardedFor) {
		headers['X-Forwarded-For'] = forwardedFor;
	}
	return createClient<paths>({
		baseUrl: apiBaseUrl(),
		headers
	});
}
