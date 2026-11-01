<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { Shield, UserRound } from '@lucide/svelte';
	import { de } from '#lib/i18n/de.js';
	import SegmentedNav from '#lib/components/SegmentedNav.svelte';

	const items = $derived([
		{
			href: resolve('settings/account'),
			label: de.nav.account,
			icon: UserRound,
			active: page.url.pathname.startsWith('/settings/account')
		},
		{
			href: resolve('settings/privacy'),
			label: de.nav.privacy,
			icon: Shield,
			active: page.url.pathname.startsWith('/settings/privacy')
		}
	]);
</script>

<SegmentedNav {items} label={de.nav.settings} class="mb-8" />
