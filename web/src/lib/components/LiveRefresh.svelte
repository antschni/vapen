<script lang="ts">
	import { browser } from '$app/env';
	import { refreshAll } from '$app/navigation';
	import { liveRefreshEnd } from '#lib/live/refresh.svelte.js';
	import { onMount } from 'svelte';

	let {
		active = false,
		intervalMs = 2000
	}: {
		active?: boolean;
		intervalMs?: number;
	} = $props();

	onMount(() => {
		if (!browser) return;
		let inFlight = false;
		const timer = setInterval(() => {
			if (!active || inFlight || document.hidden) return;
			inFlight = true;
			void refreshAll()
				.catch(() => {})
				.finally(() => {
					liveRefreshEnd();
					inFlight = false;
				});
		}, intervalMs);
		return () => clearInterval(timer);
	});
</script>
