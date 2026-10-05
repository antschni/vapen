<script lang="ts">
	import KpiCard from '#lib/components/KpiCard.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import BarSeriesChart from '#lib/components/charts/BarSeriesChart.svelte';
	import MiniLiveWidget from '#lib/components/MiniLiveWidget.svelte';
	import LiveRefresh from '#lib/components/LiveRefresh.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import { formatDurationMs, formatNumber } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const puffTrend = $derived(
		data.puffDelta === null
			? undefined
			: {
					label: `${data.puffDelta >= 0 ? '+' : ''}${formatNumber(data.puffDelta)} vs. gestern`,
					positive: data.puffDelta <= 0
				}
	);
</script>

<svelte:head>
	<title>{de.pages.overview.title} · {de.app.name}</title>
</svelte:head>

<LiveRefresh />

<PageHeader title={de.pages.overview.title} />

<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
	<KpiCard
		title={de.pages.overview.kpiPuffsToday}
		value={formatNumber(data.todayTotals?.puff_count ?? 0)}
		trend={puffTrend}
	/>
	<KpiCard
		title={de.pages.overview.kpiTimeToday}
		value={formatDurationMs(data.todayTotals?.total_duration_ms ?? 0)}
		subtitle={data.durationDelta !== null
			? `${data.durationDelta >= 0 ? '+' : ''}${formatDurationMs(Math.abs(data.durationDelta))} vs. gestern`
			: undefined}
	/>
	<KpiCard
		title={de.pages.overview.kpiAvg7}
		value={`${formatNumber(data.avg7)} ${de.pages.overview.puffsPerDay}`}
	/>
	<KpiCard
		title={de.pages.overview.kpiBattery}
		value={data.battery !== null ? `${data.battery} %` : '—'}
		subtitle={data.isCharging ? de.pages.overview.charging : undefined}
	/>
</div>

<div class="mt-8 grid gap-6 lg:grid-cols-3">
	<Card class="lg:col-span-2">
		<CardHeader>
			<CardTitle>{de.pages.overview.chartWeek}</CardTitle>
		</CardHeader>
		<CardContent>
			{#if data.barPoints.length === 0}
				<p class="text-sm text-muted-foreground">{de.empty.noData}</p>
			{:else}
				<BarSeriesChart points={data.barPoints} ariaLabel={de.pages.overview.chartWeek} />
			{/if}
		</CardContent>
	</Card>

	<Card>
		<CardHeader>
			<CardTitle>{de.pages.overview.chartTodayHourly}</CardTitle>
		</CardHeader>
		<CardContent>
			{#if data.hourlyToday.length === 0}
				<p class="text-sm text-muted-foreground">{de.empty.noData}</p>
			{:else}
				<BarSeriesChart points={data.hourlyToday} ariaLabel={de.pages.overview.chartTodayHourly} />
			{/if}
		</CardContent>
	</Card>
</div>

{#if data.firstGroupId}
	<Card class="mt-6">
		<CardContent class="pt-6">
			<MiniLiveWidget groupId={data.firstGroupId} />
		</CardContent>
	</Card>
{/if}
