export type PresenceStatus = 'vaping' | 'active' | 'idle';

const VAPING_MAX_MS = 15_000;
const ACTIVE_MAX_MS = 5 * 60_000;

/**
 * Derive live presence status (A.9). Pass `nowMs` for tests.
 */
export function derivePresenceStatus(
	vapingSince: string | null | undefined,
	lastPuffAt: string | null | undefined,
	nowMs: number = Date.now()
): PresenceStatus {
	if (vapingSince) {
		const since = Date.parse(vapingSince);
		if (Number.isFinite(since) && nowMs - since < VAPING_MAX_MS) {
			return 'vaping';
		}
	}
	if (lastPuffAt) {
		const last = Date.parse(lastPuffAt);
		if (Number.isFinite(last) && nowMs - last < ACTIVE_MAX_MS) {
			return 'active';
		}
	}
	return 'idle';
}
