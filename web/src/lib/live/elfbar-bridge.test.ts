import { describe, expect, it } from 'vitest';
import { isElfbarBridgeLive } from './elfbar-bridge.js';

describe('isElfbarBridgeLive', () => {
	const now = Date.parse('2026-10-05T12:00:00.000Z');

	it('returns true when a device reports a fresh ble_connected heartbeat', () => {
		expect(
			isElfbarBridgeLive(
				[
					{
						id: '00000000-0000-4000-8000-000000000001',
						user_id: '00000000-0000-4000-8000-000000000002',
						model: 'elfbar_master',
						name: 'Test',
						hardware_id: 'abc',
						created_at: '2026-01-01T00:00:00.000Z',
						latest_status: {
							ble_connected: true,
							recorded_at: '2026-10-05T11:59:30.000Z'
						}
					}
				],
				now
			)
		).toBe(true);
	});

	it('returns false when ble_connected is stale', () => {
		expect(
			isElfbarBridgeLive(
				[
					{
						id: '00000000-0000-4000-8000-000000000001',
						user_id: '00000000-0000-4000-8000-000000000002',
						model: 'elfbar_master',
						name: 'Test',
						hardware_id: 'abc',
						created_at: '2026-01-01T00:00:00.000Z',
						latest_status: {
							ble_connected: true,
							recorded_at: '2026-10-05T11:58:00.000Z'
						}
					}
				],
				now
			)
		).toBe(false);
	});

	it('returns false when ble_connected is missing or false', () => {
		expect(isElfbarBridgeLive([], now)).toBe(false);
	});
});
