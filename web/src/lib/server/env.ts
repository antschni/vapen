import { env } from '$env/dynamic/private';
import type { RequestEvent } from '@sveltejs/kit';

function parseBool(value: string | undefined, defaultValue: boolean): boolean {
	if (value === undefined || value === '') return defaultValue;
	return value === 'true' || value === '1';
}

function parseIntEnv(value: string | undefined, defaultValue: number): number {
	if (value === undefined || value === '') return defaultValue;
	const n = Number.parseInt(value, 10);
	return Number.isFinite(n) ? n : defaultValue;
}

export function getServerEnv() {
	return {
		apiInternalUrl: env.API_INTERNAL_URL ?? 'http://localhost:8080',
		origin: env.ORIGIN ?? 'http://localhost:5173',
		cookieSecure: parseBool(env.COOKIE_SECURE, false),
		protocolHeader: env.PROTOCOL_HEADER ?? 'x-forwarded-proto',
		hostHeader: env.HOST_HEADER ?? 'x-forwarded-host',
		addressHeader: env.ADDRESS_HEADER ?? 'x-forwarded-for',
		xffDepth: parseIntEnv(env.XFF_DEPTH, 1),
		androidPackageName: env.ANDROID_PACKAGE_NAME ?? 'dev.vapen.app',
		androidCertSha256Fingerprints: (env.ANDROID_CERT_SHA256_FINGERPRINTS ?? '')
			.split(',')
			.map((s: string) => s.trim())
			.filter(Boolean)
	};
}

/** Client IP for API rate limiting (login), forwarded as X-Forwarded-For. */
export function getClientAddress(event: RequestEvent): string | undefined {
	const {
		addressHeader,
		xffDepth
	} = getServerEnv();
	const raw = event.request.headers.get(addressHeader);
	if (!raw) {
		return event.getClientAddress();
	}
	const parts = raw.split(',').map((p) => p.trim()).filter(Boolean);
	if (parts.length === 0) {
		return event.getClientAddress();
	}
	const index = Math.max(0, parts.length - xffDepth);
	return parts[index] ?? parts[parts.length - 1];
}
