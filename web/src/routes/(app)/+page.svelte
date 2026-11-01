<script lang="ts">
	import { resolve } from '$app/paths';
	import { scale } from 'svelte/transition';
	import { ArrowRight, BatteryCharging, CalendarDays, CircleAlert, Clock, Radio } from '@lucide/svelte';
	import BatteryMeter from '#lib/components/BatteryMeter.svelte';
	import KpiCard from '#lib/components/KpiCard.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import TrendChip from '#lib/components/TrendChip.svelte';
	import BarSeriesChart from '#lib/components/charts/BarSeriesChart.svelte';
	import MiniLiveWidget from '#lib/components/MiniLiveWidget.svelte';
	import LiveRefresh from '#lib/components/LiveRefresh.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import { buttonVariants } from '#lib/components/ui/button-variants.js';
	import { formatDurationMs, formatNumber } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
	import type { PageData } from './$types';

	let { data }: { data: PageData & { elfbarBridgeLive: boolean } } = $props();

	const liveCards = $derived(data.elfbarBridgeLive);
	const firstName = $derived(data.user.display_name.trim().split(/\s+/)[0] ?? data.user.display_name);
	const puffsToday = $derived(formatNumber(data.todayTotals?.puff_count ?? 0));

	const puffTrend = $derived(
		data.puffDelta === null
			? undefined
			: {
					label: `${data.puffDelta >= 0 ? '+' : ''}${formatNumber(data.puffDelta)} ${de.pages.overview.vsYesterday}`,
					positive: data.puffDelta <= 0,
					up: data.puffDelta > 0,
					flat: data.puffDelta === 0
				}
	);

	const durationTrend = $derived(
		data.durationDelta === null
			? undefined
			: {
					label: `${data.durationDelta >= 0 ? '+' : '−'}${formatDurationMs(Math.abs(data.durationDelta))}`,
					positive: data.durationDelta <= 0,
					up: data.durationDelta > 0,
					flat: data.durationDelta === 0
				}
	);
</script>

<svelte:head>
	<title>{de.pages.overview.title} · {de.app.name}</title>
</svelte:head>

<LiveRefresh active={liveCards} />

<PageHeader eyebrow={data.todayLabel} title={de.pages.overview.greeting(firstName)} liveStats={liveCards} />

{#if data.statsFailed && data.statsErrorMessage}
	<div
		class="mb-6 flex items-center gap-2.5 rounded-2xl bg-destructive/8 px-4 py-3 text-sm text-destructive ring-1 ring-destructive/20"
		role="alert"
	>
		<CircleAlert class="size-4 shrink-0" />
		{data.statsErrorMessage}
	</div>
{/if}

<div class="grid gap-4 lg:grid-cols-3">
	<section
		class="brand-panel relative overflow-hidden rounded-3xl p-6 shadow-raised md:p-8 lg:col-span-2"
		aria-label={de.pages.overview.kpiPuffsToday}
	>
		<div class="flex flex-wrap items-start justify-between gap-x-8 gap-y-6">
			<div>
				<p class="text-sm font-medium text-white/70">{de.pages.usage.presetToday}</p>
				<div class="mt-2 flex items-baseline gap-2">
					{#key puffsToday}
						<span class="numeric text-6xl leading-none font-semibold md:text-7xl" in:scale={{ start: 0.96, duration: 200 }}>
							{puffsToday}
						</span>
					{/key}
					<span class="text-lg text-white/60">{de.pages.overview.puffsUnit}</span>
				</div>
				{#if puffTrend}
					<div class="mt-4">
						<TrendChip {...puffTrend} tone="inverted" />
					</div>
				{/if}
			</div>

			<dl class="grid min-w-44 gap-4">
				<div>
					<dt class="flex items-center gap-1.5 text-xs font-medium text-white/60">
						<Clock class="size-3.5" />
						{de.pages.overview.kpiTimeToday}
					</dt>
					<dd class="numeric mt-1 text-2xl font-semibold">
						{formatDurationMs(data.todayTotals?.total_duration_ms ?? 0)}
					</dd>
					{#if durationTrend}
						<dd class="mt-1.5">
							<TrendChip {...durationTrend} tone="inverted" />
						</dd>
					{/if}
				</div>
			</dl>
		</div>

		<div class="mt-8">
			<p class="mb-3 text-xs font-medium text-white/60">{de.pages.overview.chartTodayHourly}</p>
			{#if data.hourlyToday.length === 0}
				<p class="py-8 text-center text-sm text-white/60">{de.empty.noData}</p>
			{:else}
				<BarSeriesChart
					tone="inverted"
					height="h-32"
					animateLive={liveCards}
					points={data.hourlyToday}
					ariaLabel={de.pages.overview.chartTodayHourly}
				/>
			{/if}
		</div>
	</section>

	<div class="grid content-start gap-4 sm:grid-cols-2 lg:grid-cols-1">
		<Card class="p-5" animateLive={liveCards}>
			<div class="flex items-center justify-between gap-2">
				<p class="flex items-center gap-2 text-[13px] font-medium text-muted-foreground">
					<BatteryCharging class="size-4" />
					{de.pages.overview.kpiBattery}
				</p>
				{#if data.isCharging}
					<Badge variant="success">{de.pages.overview.charging}</Badge>
				{/if}
			</div>
			{#if data.battery !== null}
				<p class="numeric mt-3 text-[32px] leading-none font-semibold">
					{data.battery}<span class="ml-0.5 text-xl text-muted-foreground">%</span>
				</p>
				<BatteryMeter percent={data.battery} class="mt-4" />
			{:else}
				<p class="numeric mt-3 text-[32px] leading-none font-semibold text-muted-foreground">—</p>
			{/if}
			{#if data.primaryDevice}
				<a
					href={resolve('/(app)/devices/[id]', { id: data.primaryDevice.id })}
					class="group mt-4 flex items-center justify-between gap-2 rounded-lg text-sm text-muted-foreground transition-colors hover:text-foreground"
				>
					<span class="truncate">{data.primaryDevice.name}</span>
					<ArrowRight class="size-4 shrink-0 transition-transform group-hover:translate-x-0.5" />
				</a>
			{:else}
				<p class="mt-4 text-sm text-muted-foreground">{de.pages.overview.noDevice}</p>
			{/if}
		</Card>

		<KpiCard
			animateLive={liveCards}
			icon={CalendarDays}
			title={de.pages.overview.kpiAvg7}
			value={formatNumber(data.avg7)}
			subtitle={de.pages.overview.puffsPerDay}
		/>
	</div>

	<Card class={data.firstGroupId ? 'lg:col-span-2' : 'lg:col-span-3'} animateLive={liveCards}>
		<CardHeader>
			<CardTitle>{de.pages.overview.chartWeek}</CardTitle>
		</CardHeader>
		<CardContent>
			{#if data.barPoints.length === 0}
				<p class="py-12 text-center text-sm text-muted-foreground">{de.empty.noData}</p>
			{:else}
				<BarSeriesChart animateLive={liveCards} points={data.barPoints} ariaLabel={de.pages.overview.chartWeek} />
			{/if}
		</CardContent>
	</Card>

	{#if data.firstGroupId}
		<Card>
			<CardHeader>
				<CardTitle class="flex items-center gap-2">
					<Radio class="size-4 text-success" />
					{de.live.widgetTitle}
				</CardTitle>
				{#snippet actions()}
					<a
						href={resolve('/(app)/groups/[id]', { id: data.firstGroupId! })}
						class={buttonVariants({ variant: 'ghost', size: 'sm' })}
					>
						{de.pages.devices.viewDetail}
						<ArrowRight />
					</a>
				{/snippet}
			</CardHeader>
			<CardContent>
				<MiniLiveWidget groupId={data.firstGroupId} />
			</CardContent>
		</Card>
	{/if}
</div>
