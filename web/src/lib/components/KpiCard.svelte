<script lang="ts">
	import type { Component } from 'svelte';
	import { scale } from 'svelte/transition';
	import { TrendingDown, TrendingUp } from '@lucide/svelte';
	import Card from '#lib/components/ui/card.svelte';
	import { getLiveRefresh } from '#lib/live/refresh.svelte.js';
	import { cn } from '#lib/utils.js';

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
		trend?: { label: string; positive: boolean; up: boolean };
		icon?: Component<{ class?: string }>;
		animateLive?: boolean;
	} = $props();

	const live = $derived(getLiveRefresh());
	let valueFlash = $state(false);

	$effect(() => {
		if (!animateLive) return;
		void live.tick;
		void value;
		valueFlash = true;
		const timer = setTimeout(() => {
			valueFlash = false;
		}, 550);
		return () => clearTimeout(timer);
	});
</script>

<Card class={cn('live-kpi-flash p-5', valueFlash && 'ring-2 ring-primary/20')}>
	<div class="flex items-center justify-between gap-2">
		<p class="text-[13px] font-medium text-muted-foreground">{title}</p>
		{#if Icon}
			<span class="flex size-8 items-center justify-center rounded-lg bg-primary/[0.08] text-primary">
				<Icon class="size-4" />
			</span>
		{/if}
	</div>
	{#key value}
		<p class="mt-2 text-2xl font-semibold tracking-tight tabular-nums" in:scale={{ start: 0.96, duration: 200 }}>
			{value}
		</p>
	{/key}
	{#if trend || subtitle}
		<div class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs">
			{#if trend}
				{@const TrendIcon = trend.up ? TrendingUp : TrendingDown}
				<span
					class={[
						'inline-flex items-center gap-1 font-medium',
						trend.positive ? 'text-emerald-600 dark:text-emerald-400' : 'text-amber-600 dark:text-amber-400'
					]}
				>
					<TrendIcon class="size-3.5" />
					{trend.label}
				</span>
			{/if}
			{#if subtitle}
				<span class="text-muted-foreground">{subtitle}</span>
			{/if}
		</div>
	{/if}
</Card>
