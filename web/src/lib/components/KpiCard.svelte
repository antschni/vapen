<script lang="ts">
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import { getLiveRefresh } from '#lib/live/refresh.svelte.js';
	import { scale } from 'svelte/transition';

	let {
		title,
		value,
		subtitle = undefined,
		trend = undefined,
		animateLive = false
	}: {
		title: string;
		value: string;
		subtitle?: string;
		trend?: { label: string; positive: boolean };
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

<Card
	class="transition-shadow hover:shadow-md {valueFlash
		? 'live-kpi-flash ring-2 ring-primary/25'
		: ''}"
>
	<CardHeader class="pb-2">
		<CardTitle class="text-sm font-medium text-muted-foreground">{title}</CardTitle>
	</CardHeader>
	<CardContent>
		{#key value}
			<p
				class="text-2xl font-bold tabular-nums"
				in:scale={{ start: 0.94, duration: 220 }}
			>
				{value}
			</p>
		{/key}
		{#if subtitle}
			<p class="mt-1 text-xs text-muted-foreground">{subtitle}</p>
		{/if}
		{#if trend}
			<p
				class="mt-1 text-xs {trend.positive
					? 'text-emerald-600 dark:text-emerald-400'
					: 'text-amber-600 dark:text-amber-400'}"
			>
				{trend.label}
			</p>
		{/if}
	</CardContent>
</Card>
