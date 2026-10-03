/**
 * Allow only same-origin relative paths (open-redirect safe).
 * Returns a normalized path starting with `/` or null if invalid.
 */
export function validateRedirectTo(value: string | null | undefined): string | null {
	if (!value || typeof value !== 'string') return null;
	const trimmed = value.trim();
	if (!trimmed.startsWith('/')) return null;
	if (trimmed.startsWith('//')) return null;
	if (trimmed.includes('://')) return null;
	if (trimmed.includes('\\')) return null;
	try {
		const url = new URL(trimmed, 'http://local.invalid');
		if (url.origin !== 'http://local.invalid') return null;
		return url.pathname + url.search + url.hash;
	} catch {
		return null;
	}
}
