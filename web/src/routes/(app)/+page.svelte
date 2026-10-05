<script lang="ts">
	import { resolve } from '$app/paths';
	import { BatteryMedium, CalendarDays, CircleAlert, Clock, Wind } from '@lucide/svelte';
	import KpiCard from '#lib/components/KpiCard.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import BarSeriesChart from '#lib/components/charts/BarSeriesChart.svelte';
	import MiniLiveWidget from '#lib/components/MiniLiveWidget.svelte';
	import LiveRefresh from '#lib/components/LiveRefresh.svelte';
	import LiveStatsPulse from '#lib/components/LiveStatsPulse.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import { buttonVariants } from '#lib/components/ui/button-variants.js';
	import { formatDurationMs, formatNumber } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const puffTrend = $derived(
		data.puffDelta === null
			? undefined
			: {
					label: `${data.puffDelta >= 0 ? '+' : ''}${formatNumber(data.puffDelta)} vs. gestern`,
					positive: data.puffDelta <= 0,
					up: data.puffDelta > 0
				}
	);

	const durationTrend = $derived(
		data.durationDelta === null
			? undefined
			: {
					label: `${data.durationDelta >= 0 ? '+' : '−'}${formatDurationMs(Math.abs(data.durationDelta))} vs. gestern`,
					positive: data.durationDelta <= 0,
					up: data.durationDelta > 0
				}
	);
</script>

<svelte:head>
	<title>{de.pages.overview.title} · {de.app.name}</title>
</svelte:head>

<LiveRefresh />

<PageHeader title={de.pages.overview.title} liveStats />

{#if data.statsFailed && data.statsErrorMessage}
	<div
		class="mb-6 flex items-center gap-2.5 rounded-xl border border-destructive/20 bg-destructive/[0.06] px-4 py-3 text-sm text-destructive"
		role="alert"
	>
		<CircleAlert class="size-4 shrink-0" />
		{data.statsErrorMessage}
	</div>
{/if}

<div class="space-y-6">
	<LiveStatsPulse class="grid gap-4 rounded-xl sm:grid-cols-2 xl:grid-cols-4">
		<KpiCard
			animateLive
			icon={Wind}
			title={de.pages.overview.kpiPuffsToday}
			value={formatNumber(data.todayTotals?.puff_count ?? 0)}
			trend={puffTrend}
		/>
		<KpiCard
			animateLive
			icon={Clock}
			title={de.pages.overview.kpiTimeToday}
			value={formatDurationMs(data.todayTotals?.total_duration_ms ?? 0)}
			trend={durationTrend}
		/>
		<KpiCard
			animateLive
			icon={CalendarDays}
			title={de.pages.overview.kpiAvg7}
			value={formatNumber(data.avg7)}
			subtitle={de.pages.overview.puffsPerDay}
		/>
		<KpiCard
			animateLive
			icon={BatteryMedium}
			title={de.pages.overview.kpiBattery}
			value={data.battery !== null ? `${data.battery} %` : '—'}
			subtitle={data.isCharging ? de.pages.overview.charging : undefined}
		/>
	</LiveStatsPulse>

	<LiveStatsPulse class="grid gap-4 rounded-xl lg:grid-cols-5">
		<Card class="lg:col-span-3">
			<CardHeader>
				<CardTitle>{de.pages.overview.chartWeek}</CardTitle>
			</CardHeader>
			<CardContent>
				{#if data.barPoints.length === 0}
					<p class="py-12 text-center text-sm text-muted-foreground">{de.empty.noData}</p>
				{:else}
					<BarSeriesChart animateLive points={data.barPoints} ariaLabel={de.pages.overview.chartWeek} />
				{/if}
			</CardContent>
		</Card>

		<Card class="lg:col-span-2">
			<CardHeader>
				<CardTitle>{de.pages.overview.chartTodayHourly}</CardTitle>
			</CardHeader>
			<CardContent>
				{#if data.hourlyToday.length === 0}
					<p class="py-12 text-center text-sm text-muted-foreground">{de.empty.noData}</p>
				{:else}
					<BarSeriesChart animateLive points={data.hourlyToday} ariaLabel={de.pages.overview.chartTodayHourly} />
				{/if}
			</CardContent>
		</Card>
	</LiveStatsPulse>

	{#if data.firstGroupId}
		<Card>
			<CardHeader>
				<CardTitle>{de.live.widgetTitle}</CardTitle>
				{#snippet actions()}
					<a
						href={resolve('/(app)/groups/[id]', { id: data.firstGroupId! })}
						class={buttonVariants({ variant: 'ghost', size: 'sm' })}
					>
						{de.pages.devices.viewDetail}
					</a>
				{/snippet}
			</CardHeader>
			<CardContent>
				<MiniLiveWidget groupId={data.firstGroupId} />
			</CardContent>
		</Card>
	{/if}
</div>
