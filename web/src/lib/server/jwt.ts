/** Decode JWT `exp` (seconds since epoch) without verification. */
export function decodeJwtExp(accessToken: string): number | null {
	const parts = accessToken.split('.');
	if (parts.length !== 3) return null;
	try {
		const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'))) as {
			exp?: number;
		};
		return typeof payload.exp === 'number' ? payload.exp : null;
	} catch {
		return null;
	}
}

export function accessTokenExpiresWithinSeconds(accessToken: string, withinSeconds: number): boolean {
	const exp = decodeJwtExp(accessToken);
	if (exp === null) return true;
	const nowSec = Math.floor(Date.now() / 1000);
	return exp - nowSec < withinSeconds;
}
