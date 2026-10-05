<script lang="ts">
	import type { Snippet } from 'svelte';
	import { ChevronLeft } from '@lucide/svelte';
	import LiveStatsBadge from '#lib/components/LiveStatsBadge.svelte';

	let {
		title,
		description = undefined,
		liveStats = false,
		back = undefined,
		actions
	}: {
		title: string;
		description?: string;
		liveStats?: boolean;
		back?: { href: string; label: string };
		actions?: Snippet;
	} = $props();
</script>

<header class="mb-6 md:mb-8">
	{#if back}
		<a
			href={back.href}
			class="-ml-1 mb-3 inline-flex items-center gap-0.5 rounded-md px-1 text-sm text-muted-foreground transition-colors hover:text-foreground focus-visible:ring-[3px] focus-visible:ring-ring/30 focus-visible:outline-none"
		>
			<ChevronLeft class="size-4" aria-hidden="true" />
			{back.label}
		</a>
	{/if}
	<div class="flex flex-wrap items-end justify-between gap-x-4 gap-y-3">
		<div class="min-w-0 flex-1">
			<h1 class="truncate text-2xl font-semibold tracking-tight md:text-[28px] md:leading-9">{title}</h1>
			{#if description}
				<p class="mt-1 max-w-2xl text-sm text-muted-foreground">{description}</p>
			{/if}
		</div>
		{#if liveStats || actions}
			<div class="flex flex-wrap items-center gap-2">
				{#if liveStats}
					<LiveStatsBadge active />
				{/if}
				{@render actions?.()}
			</div>
		{/if}
	</div>
</header>
