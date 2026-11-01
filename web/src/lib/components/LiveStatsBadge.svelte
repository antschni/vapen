<script lang="ts">
	import { de } from '#lib/i18n/de.js';

	let { active = false }: { active?: boolean } = $props();
</script>

{#if active}
	<div
		class="inline-flex h-8 items-center gap-2 rounded-full bg-success/12 px-3 text-xs font-medium text-[color-mix(in_oklch,var(--success)_75%,var(--foreground))]"
		role="status"
		aria-live="polite"
		title={de.live.statsHint}
	>
		<span class="relative flex size-2 shrink-0" aria-hidden="true">
			<span
				class="absolute inline-flex size-full rounded-full bg-success opacity-50 motion-safe:animate-ping"
			></span>
			<span class="relative inline-flex size-2 rounded-full bg-success"></span>
		</span>
		{de.live.statsLabel}
	</div>
{/if}
