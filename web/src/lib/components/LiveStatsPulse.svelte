<script lang="ts">
	import type { Snippet } from 'svelte';
	import { getLiveRefresh } from '#lib/live/refresh.svelte.js';

	let {
		children,
		class: className = ''
	}: {
		children?: Snippet;
		class?: string;
	} = $props();

	const live = $derived(getLiveRefresh());
	let pulse = $state(false);

	$effect(() => {
		live.tick;
		pulse = true;
		const timer = setTimeout(() => {
			pulse = false;
		}, 650);
		return () => clearTimeout(timer);
	});
</script>

<div class="live-stats-pulse-wrap {className}" class:live-stats-pulse-active={pulse}>
	{@render children?.()}
</div>
