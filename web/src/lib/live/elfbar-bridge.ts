import type { components } from '#lib/api/schema.d.ts';

type Device = components['schemas']['Device'];

/** Heartbeats from the mobile app while BLE is live (see bridgeLinkId, 45s). */
export const ELFBAR_BRIDGE_STALE_MS = 90_000;

export function isElfbarBridgeLive(
	devices: Device[],
	nowMs: number = Date.now()
): boolean {
	for (const device of devices) {
		const status = device.latest_status;
		if (status?.ble_connected !== true) continue;

		const recordedAt = status.recorded_at ? Date.parse(status.recorded_at) : NaN;
		if (Number.isFinite(recordedAt) && nowMs - recordedAt < ELFBAR_BRIDGE_STALE_MS) {
			return true;
		}
	}
	return false;
}
