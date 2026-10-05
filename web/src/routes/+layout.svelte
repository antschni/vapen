<script lang="ts">
	import '../app.css';
	import favicon from '#lib/assets/favicon.svg';
	import PwaReloadPrompt from '#lib/components/PwaReloadPrompt.svelte';
	import { afterNavigate } from '$app/navigation';
	import { browser } from '$app/env';

	let { children } = $props();

	afterNavigate(async ({ shallow }) => {
		if (shallow) return;
		if (!browser || !('serviceWorker' in navigator)) return;
		const registration = await navigator.serviceWorker.getRegistration();
		await registration?.update();
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} type="image/svg+xml" />
	<link rel="icon" href="/pwa/favicon.ico" sizes="any" />
	<link rel="apple-touch-icon" href="/pwa/apple-touch-icon-180x180.png" />
	<meta name="theme-color" content="#4466aa" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
	<meta name="apple-mobile-web-app-title" content="Vapen" />
</svelte:head>

{@render children()}
<PwaReloadPrompt />
