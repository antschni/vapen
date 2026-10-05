<script lang="ts">
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';

	let {
		title,
		value,
		subtitle = undefined,
		trend = undefined
	}: {
		title: string;
		value: string;
		subtitle?: string;
		trend?: { label: string; positive: boolean };
	} = $props();
</script>

<Card class="transition-shadow hover:shadow-md">
	<CardHeader class="pb-2">
		<CardTitle class="text-sm font-medium text-muted-foreground">{title}</CardTitle>
	</CardHeader>
	<CardContent>
		<p class="text-2xl font-bold tabular-nums">{value}</p>
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
