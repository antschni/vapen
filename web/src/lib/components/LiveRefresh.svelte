<script lang="ts">
	import { browser } from '$app/env';
	import { refreshAll } from '$app/navigation';
	import { liveRefreshEnd, liveRefreshStart } from '#lib/live/refresh.svelte.js';
	import { onMount } from 'svelte';

	let { intervalMs = 2000 }: { intervalMs?: number } = $props();

	onMount(() => {
		if (!browser) return;
		let inFlight = false;
		const timer = setInterval(() => {
			if (inFlight || document.hidden) return;
			inFlight = true;
			liveRefreshStart();
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
