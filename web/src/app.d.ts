/// <reference types="vite-plugin-pwa/svelte" />

import type { ApiClient } from '$lib/server/api';
import type { components } from '$lib/api/schema.d.ts';

declare global {
	namespace App {
		interface Locals {
			user?: Pick<
				components['schemas']['User'],
				'id' | 'email' | 'display_name' | 'timezone'
			>;
			api?: ApiClient;
		}
		interface PageData {
			user?: App.Locals['user'];
			groups?: components['schemas']['GroupSummary'][];
		}
	}
}

export {};
