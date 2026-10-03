import type { components } from '$lib/api/schema.d.ts';

export type PrivacyFlag =
	| 'share_live_status'
	| 'share_usage_summary'
	| 'share_usage_detail'
	| 'share_device_stats'
	| 'show_in_leaderboard';

export const PRIVACY_FLAGS: PrivacyFlag[] = [
	'share_live_status',
	'share_usage_summary',
	'share_usage_detail',
	'share_device_stats',
	'show_in_leaderboard'
];

export type PrivacySettings = components['schemas']['PrivacySettings'];
export type PrivacyOverrides = components['schemas']['PrivacyOverrides'];

export function overrideFromForm(value: string): boolean | null {
	if (value === 'on') return true;
	if (value === 'off') return false;
	return null;
}

export function formValueFromOverride(value: boolean | null | undefined): 'inherit' | 'on' | 'off' {
	if (value === true) return 'on';
	if (value === false) return 'off';
	return 'inherit';
}
