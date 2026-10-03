import { describe, expect, it } from 'vitest';
import { validateRedirectTo } from './redirect';

describe('validateRedirectTo', () => {
	it('allows relative paths', () => {
		expect(validateRedirectTo('/usage')).toBe('/usage');
		expect(validateRedirectTo('/groups?id=1')).toBe('/groups?id=1');
	});

	it('rejects absolute URLs and protocol-relative', () => {
		expect(validateRedirectTo('https://evil.com')).toBeNull();
		expect(validateRedirectTo('//evil.com')).toBeNull();
	});

	it('rejects null and empty', () => {
		expect(validateRedirectTo(null)).toBeNull();
		expect(validateRedirectTo('')).toBeNull();
	});
});
