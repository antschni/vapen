<script lang="ts">
	import { browser } from '$app/env';
	import { refreshAll } from '$app/navigation';
	import { onMount } from 'svelte';

	let { intervalMs = 2000 }: { intervalMs?: number } = $props();

	onMount(() => {
		if (!browser) return;
		let refreshing = false;
		const timer = setInterval(() => {
			if (refreshing || document.hidden) return;
			refreshing = true;
			void refreshAll().finally(() => {
				refreshing = false;
			});
		}, intervalMs);
		return () => clearInterval(timer);
	});
</script>
