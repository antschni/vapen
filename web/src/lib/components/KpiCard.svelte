<script lang="ts">
	import type { Component } from 'svelte';
	import { scale } from 'svelte/transition';
	import Card from '#lib/components/ui/card.svelte';
	import TrendChip from '#lib/components/TrendChip.svelte';

	let {
		title,
		value,
		subtitle = undefined,
		trend = undefined,
		icon: Icon = undefined,
		animateLive = false
	}: {
		title: string;
		value: string;
		subtitle?: string;
		trend?: { label: string; positive: boolean; up: boolean; flat?: boolean };
		icon?: Component<{ class?: string }>;
		animateLive?: boolean;
	} = $props();
</script>

<Card class="flex flex-col p-5" {animateLive}>
	<div class="flex items-center gap-2 text-muted-foreground">
		{#if Icon}
			<Icon class="size-4" />
		{/if}
		<p class="text-[13px] font-medium">{title}</p>
	</div>
	{#key value}
		<p class="numeric mt-3 text-[32px] leading-none font-semibold" in:scale={{ start: 0.96, duration: 200 }}>
			{value}
		</p>
	{/key}
	{#if trend || subtitle}
		<div class="mt-3 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs">
			{#if trend}
				<TrendChip {...trend} />
			{/if}
			{#if subtitle}
				<span class="text-muted-foreground">{subtitle}</span>
			{/if}
		</div>
	{/if}
</Card>
