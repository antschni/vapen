import type { components } from '$lib/api/schema.d.ts';

export type SessionUser = Pick<
	components['schemas']['User'],
	'id' | 'email' | 'display_name' | 'timezone'
>;
