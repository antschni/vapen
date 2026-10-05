<script lang="ts">
	import { de } from '#lib/i18n/de.js';
	import { getLiveRefresh } from '#lib/live/refresh.svelte.js';

	const live = $derived(getLiveRefresh());
</script>

<div
	class="live-stats-badge inline-flex items-center gap-2 rounded-full border border-emerald-500/25 bg-emerald-500/10 px-3 py-1.5 text-xs font-medium text-emerald-800 shadow-sm dark:text-emerald-200"
	role="status"
	aria-live="polite"
	title={de.live.statsHint}
>
	<span class="relative flex h-2.5 w-2.5 shrink-0" aria-hidden="true">
		<span
			class="absolute inline-flex h-full w-full rounded-full bg-emerald-500 opacity-40 motion-safe:animate-ping motion-reduce:animate-none"
		></span>
		<span
			class="relative inline-flex h-2.5 w-2.5 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.65)] {live.refreshing
				? 'motion-safe:scale-110 motion-safe:animate-pulse motion-reduce:animate-none'
				: ''}"
		></span>
	</span>
	<span class="tracking-wide uppercase">{de.live.statsLabel}</span>
	{#if live.refreshing}
		<span class="text-[10px] font-normal normal-case text-emerald-700/80 dark:text-emerald-300/80">
			{de.live.statsSyncing}
		</span>
	{/if}
</div>
