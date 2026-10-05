<script lang="ts">
	import { de } from '#lib/i18n/de.js';
	import { getLiveRefresh } from '#lib/live/refresh.svelte.js';

	const live = $derived(getLiveRefresh());
</script>

<div
	class="inline-flex h-7 items-center gap-2 rounded-full border border-emerald-500/20 bg-emerald-500/[0.07] px-2.5 text-xs font-medium text-emerald-700 dark:text-emerald-300"
	role="status"
	aria-live="polite"
	title={de.live.statsHint}
>
	<span class="relative flex size-2 shrink-0" aria-hidden="true">
		<span
			class="absolute inline-flex size-full rounded-full bg-emerald-500 opacity-50 motion-safe:animate-ping"
		></span>
		<span class="relative inline-flex size-2 rounded-full bg-emerald-500"></span>
	</span>
	{live.refreshing ? de.live.statsSyncing : de.live.statsLabel}
</div>
