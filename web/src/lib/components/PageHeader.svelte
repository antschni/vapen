<script lang="ts">
	import type { Snippet } from 'svelte';
	import { ArrowLeft } from '@lucide/svelte';
	import LiveStatsBadge from '#lib/components/LiveStatsBadge.svelte';

	let {
		title,
		eyebrow = undefined,
		description = undefined,
		liveStats = false,
		back = undefined,
		actions
	}: {
		title: string;
		eyebrow?: string;
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
			class="group mb-4 inline-flex items-center gap-1.5 rounded-full text-sm text-muted-foreground transition-colors hover:text-foreground focus-visible:ring-[3px] focus-visible:ring-ring/30 focus-visible:outline-none"
		>
			<ArrowLeft class="size-4 transition-transform group-hover:-translate-x-0.5" aria-hidden="true" />
			{back.label}
		</a>
	{/if}
	<div class="flex flex-wrap items-end justify-between gap-x-4 gap-y-3">
		<div class="min-w-0 flex-1">
			{#if eyebrow}
				<p class="mb-1 text-sm font-medium text-muted-foreground">{eyebrow}</p>
			{/if}
			<h1 class="truncate text-[28px] leading-9 font-semibold tracking-[-0.025em] md:text-4xl md:leading-11">
				{title}
			</h1>
			{#if description}
				<p class="mt-1.5 max-w-2xl text-[15px] text-muted-foreground">{description}</p>
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
