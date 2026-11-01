<script lang="ts">
	import { format } from 'date-fns';
	import { de as dateFnsDe } from 'date-fns/locale';
	import { resolve } from '$app/paths';
	import { goto } from '$app/navigation';
	import { enhance } from '$app/forms';
	import { SvelteURLSearchParams } from 'svelte/reactivity';
	import { Clock, Download, Wind } from '@lucide/svelte';
	import LiveRefresh from '#lib/components/LiveRefresh.svelte';
	import KpiCard from '#lib/components/KpiCard.svelte';
	import BarSeriesChart from '#lib/components/charts/BarSeriesChart.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import HeatmapChart from '#lib/components/charts/HeatmapChart.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import { buttonVariants } from '#lib/components/ui/button-variants.js';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import CardDescription from '#lib/components/ui/card-description.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import Select from '#lib/components/ui/select.svelte';
	import { formatDurationMs, formatNumber } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
	import { notify } from '#lib/notifications.svelte.js';
	import type { components } from '#lib/api/schema.d.ts';
	import type { PageData, ActionData } from './$types';

	type Puff = components['schemas']['Puff'];

	let { data }: { data: PageData & { elfbarBridgeLive: boolean }; form?: ActionData } = $props();

	const liveCards = $derived(data.elfbarBridgeLive);

	let extraPuffs = $state<Puff[]>([]);
	let nextCursor = $state<string | null>(null);
	let loadingMore = $state(false);
	let preset = $state<'today' | '7d' | '30d' | '90d' | 'year' | 'custom'>('7d');
	let bucket = $state<'hour' | 'day' | 'week' | 'month'>('day');
	let deviceId = $state('');
	let userId = $state('');
	let seenFilterKey = $state<string | null>(null);

	// Rolling presets end at "now", so their from/to change on every live refresh;
	// only custom ranges belong in the key, otherwise loaded pages get wiped.
	const filterKey = $derived(
		[
			data.filters.preset,
			data.filters.bucket,
			data.filters.deviceId ?? '',
			data.filters.userId ?? '',
			data.filters.minDurationMs ?? '',
			data.filters.maxDurationMs ?? '',
			data.filters.preset === 'custom' ? data.filters.fromIso : '',
			data.filters.preset === 'custom' ? data.filters.toIso : ''
		].join('|')
	);

	$effect.pre(() => {
		const key = filterKey;
		const cursor = data.puffNextCursor;
		if (seenFilterKey !== key) {
			seenFilterKey = key;
			preset = data.filters.preset;
			bucket = data.filters.bucket;
			deviceId = data.filters.deviceId ?? '';
			userId = data.filters.userId ?? '';
			extraPuffs = [];
			nextCursor = cursor;
			return;
		}
		if (extraPuffs.length === 0) {
			nextCursor = cursor;
		}
	});

	function applyFilters(event: SubmitEvent) {
		event.preventDefault();
		const params = new SvelteURLSearchParams();
		params.set('preset', preset);
		params.set('bucket', bucket);
		if (deviceId) params.set('device_id', deviceId);
		if (userId) params.set('user_id', userId);
		if (data.filters.minDurationMs !== undefined) {
			params.set('min_duration_ms', String(data.filters.minDurationMs));
		}
		if (data.filters.maxDurationMs !== undefined) {
			params.set('max_duration_ms', String(data.filters.maxDurationMs));
		}
		const query = params.toString();
		void goto(query ? `${resolve('usage')}?${query}` : resolve('usage'));
	}

	const presets = [
		{ value: 'today', label: de.pages.usage.presetToday },
		{ value: '7d', label: de.pages.usage.preset7d },
		{ value: '30d', label: de.pages.usage.preset30d },
		{ value: '90d', label: de.pages.usage.preset90d },
		{ value: 'year', label: de.pages.usage.presetYear }
	] as const;

	// Live refreshes can shift rows between the first page and loaded pages;
	// drop duplicates so the keyed #each never sees the same id twice.
	const allPuffs = $derived.by(() => {
		const firstPageIds = new Set(data.puffs.map((p) => p.id));
		return [...data.puffs, ...extraPuffs.filter((p) => !firstPageIds.has(p.id))];
	});

	const chartPoints = $derived(
		data.series.map((s) => ({
			label: format(new Date(s.label), data.filters.bucket === 'hour' ? 'HH:mm' : 'dd.MM.', {
				locale: dateFnsDe
			}),
			durationMs: s.durationMs,
			puffCount: s.puffCount
		}))
	);

	const exportHref = $derived.by(() => {
		const q = new SvelteURLSearchParams();
		q.set('preset', data.filters.preset);
		q.set('bucket', data.filters.bucket);
		if (data.filters.deviceId) q.set('device_id', data.filters.deviceId);
		if (data.filters.userId) q.set('user_id', data.filters.userId);
		if (data.filters.preset === 'custom') {
			q.set('from', data.filters.fromIso);
			q.set('to', data.filters.toIso);
		}
		if (data.filters.minDurationMs !== undefined) {
			q.set('min_duration_ms', String(data.filters.minDurationMs));
		}
		if (data.filters.maxDurationMs !== undefined) {
			q.set('max_duration_ms', String(data.filters.maxDurationMs));
		}
		return resolve(`usage/export.csv?${q}`);
	});

	const puffDelta = $derived(
		data.stats
			? data.stats.totals.puff_count - data.stats.previous_period.puff_count
			: null
	);
	const durationDelta = $derived(
		data.stats
			? data.stats.totals.total_duration_ms - data.stats.previous_period.total_duration_ms
			: null
	);

	function histogramFromPuffs(puffs: Puff[]) {
		const bins = [0, 1000, 2000, 3000, 5000, 10000, 60000];
		const counts = bins.map((lower, i) => {
			const upper = bins[i + 1] ?? Infinity;
			return {
				lower,
				upper: bins[i + 1] ?? null,
				count: puffs.filter((p) => p.duration_ms >= lower && p.duration_ms < upper).length
			};
		});
		return counts.filter((b) => b.count > 0);
	}

	const histogram = $derived(histogramFromPuffs(allPuffs));
	const histogramMax = $derived(histogram.reduce((m, b) => Math.max(m, b.count), 1));
</script>

<svelte:head>
	<title>{de.pages.usage.title} · {de.app.name}</title>
</svelte:head>

<LiveRefresh active={liveCards} />

<PageHeader title={de.pages.usage.title} liveStats={liveCards}>
	{#snippet actions()}
		<a href={exportHref} class={buttonVariants({ variant: 'outline', size: 'sm' })}>
			<Download />
			{de.pages.usage.exportCsv}
		</a>
	{/snippet}
</PageHeader>

<div class="space-y-6">
	<Card class="p-4 sm:p-5">
		<form method="GET" class="space-y-4" onsubmit={applyFilters}>
			<fieldset class="-mx-1 overflow-x-auto px-1">
				<legend class="sr-only">{de.pages.usage.preset}</legend>
				<div class="inline-flex rounded-full bg-muted p-1">
					{#each presets as option (option.value)}
						<label
							class="cursor-pointer rounded-full px-3.5 py-1.5 text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground has-checked:bg-card has-checked:text-foreground has-checked:shadow-card has-focus-visible:ring-[3px] has-focus-visible:ring-ring/30"
						>
							<input type="radio" class="sr-only" name="preset" value={option.value} bind:group={preset} />
							{option.label}
						</label>
					{/each}
				</div>
			</fieldset>
			<div class="grid items-end gap-3 sm:grid-cols-3 lg:grid-cols-[repeat(3,minmax(0,1fr))_auto]">
				<div class="space-y-1.5">
					<Label for="bucket" class="text-xs text-muted-foreground">{de.pages.usage.bucket}</Label>
					<Select id="bucket" name="bucket" bind:value={bucket}>
						<option value="hour">{de.pages.usage.bucketHour}</option>
						<option value="day">{de.pages.usage.bucketDay}</option>
						<option value="week">{de.pages.usage.bucketWeek}</option>
						<option value="month">{de.pages.usage.bucketMonth}</option>
					</Select>
				</div>
				<div class="space-y-1.5">
					<Label for="device_id" class="text-xs text-muted-foreground">{de.pages.usage.device}</Label>
					<Select id="device_id" name="device_id" bind:value={deviceId}>
						<option value="">{de.pages.usage.deviceAll}</option>
						{#each data.devices as device (device.id)}
							<option value={device.id}>{device.name}</option>
						{/each}
					</Select>
				</div>
				<div class="space-y-1.5">
					<Label for="user_id" class="text-xs text-muted-foreground">{de.pages.usage.person}</Label>
					<Select id="user_id" name="user_id" bind:value={userId}>
						<option value="">{de.pages.usage.personSelf}</option>
						{#each data.detailMembers as member (member.id)}
							<option value={member.id}>{member.name}</option>
						{/each}
					</Select>
				</div>
				<Button type="submit" class="sm:col-span-3 lg:col-span-1">{de.pages.usage.applyFilters}</Button>
			</div>
		</form>
	</Card>

	<div class="space-y-6">
		{#if data.stats}
			<div class="grid gap-4 sm:grid-cols-2">
				<KpiCard
					animateLive={liveCards}
					icon={Wind}
					title={de.pages.usage.puffsDelta}
					value={formatNumber(data.stats.totals.puff_count)}
					trend={puffDelta !== null
						? {
								label: `${puffDelta >= 0 ? '+' : ''}${formatNumber(puffDelta)} ${de.pages.usage.vsPrevious}`,
								positive: puffDelta <= 0,
								up: puffDelta > 0,
								flat: puffDelta === 0
							}
						: undefined}
				/>
				<KpiCard
					animateLive={liveCards}
					icon={Clock}
					title={de.pages.usage.durationDelta}
					value={formatDurationMs(data.stats.totals.total_duration_ms)}
					trend={durationDelta !== null
						? {
								label: `${durationDelta >= 0 ? '+' : '−'}${formatDurationMs(Math.abs(durationDelta))} ${de.pages.usage.vsPrevious}`,
								positive: durationDelta <= 0,
								up: durationDelta > 0,
								flat: durationDelta === 0
							}
						: undefined}
				/>
			</div>
		{/if}

		<div class="grid gap-4 lg:grid-cols-2">
			<Card animateLive={liveCards}>
				<CardHeader>
					<CardTitle>{de.pages.usage.chartSeries}</CardTitle>
				</CardHeader>
				<CardContent>
					{#if chartPoints.length === 0}
						<p class="py-12 text-center text-sm text-muted-foreground">{de.empty.noData}</p>
					{:else}
						<BarSeriesChart animateLive={liveCards} points={chartPoints} ariaLabel={de.pages.usage.chartSeries} />
					{/if}
				</CardContent>
			</Card>
			<Card animateLive={liveCards}>
				<CardHeader>
					<CardTitle>{de.pages.usage.chartHeatmap}</CardTitle>
				</CardHeader>
				<CardContent>
					{#if data.heatmap.length === 0}
						<p class="py-12 text-center text-sm text-muted-foreground">{de.empty.noData}</p>
					{:else}
						<HeatmapChart cells={data.heatmap} ariaLabel={de.pages.usage.chartHeatmap} />
					{/if}
				</CardContent>
			</Card>
		</div>
	</div>

	<div class={['grid gap-4', histogram.length > 0 && 'lg:grid-cols-3']}>
		<Card class="overflow-hidden lg:col-span-2">
			<CardHeader>
				<CardTitle>{de.pages.usage.puffTable}</CardTitle>
				{#if allPuffs.length > 0}
					<CardDescription>{de.pages.usage.loadedCount(formatNumber(allPuffs.length))}</CardDescription>
				{/if}
			</CardHeader>
			{#if allPuffs.length === 0}
				<CardContent>
					<p class="py-8 text-center text-sm text-muted-foreground">{de.pages.usage.noPuffs}</p>
				</CardContent>
			{:else}
				<div class="max-h-[28rem] overflow-auto border-t border-border">
					<table class="w-full text-sm">
						<thead class="sticky top-0 z-10 bg-surface/95 backdrop-blur">
							<tr class="text-left text-xs font-medium text-muted-foreground">
								<th class="px-5 py-3 font-medium sm:px-6">{de.pages.usage.startedAt}</th>
								<th class="px-5 py-3 font-medium sm:px-6">{de.pages.usage.duration}</th>
								<th class="px-5 py-3 text-right font-medium sm:px-6">{de.pages.usage.source}</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-border">
							{#each allPuffs as puff (puff.id)}
								<tr class="transition-colors hover:bg-muted/40">
									<td class="px-5 py-3 whitespace-nowrap tabular-nums sm:px-6">
										{format(new Date(puff.started_at), 'dd.MM.yyyy · HH:mm:ss', { locale: dateFnsDe })}
									</td>
									<td class="px-5 py-3 font-medium tabular-nums sm:px-6">{formatDurationMs(puff.duration_ms)}</td>
									<td class="px-5 py-3 text-right sm:px-6">
										<Badge variant={puff.source === 'live' ? 'success' : 'secondary'}>
											{puff.source === 'live' ? de.pages.usage.sourceLive : de.pages.usage.sourceHistory}
										</Badge>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
				{#if nextCursor}
					<form
						method="POST"
						action="?/loadMore"
						class="flex justify-center border-t border-border p-3"
						use:enhance={() => {
							loadingMore = true;
							return async ({ result }) => {
								loadingMore = false;
								if (result.type === 'success' && result.data) {
									const d = result.data as { items: Puff[]; next_cursor: string | null };
									extraPuffs = [...extraPuffs, ...d.items];
									nextCursor = d.next_cursor;
									return;
								}
								const message =
									result.type === 'failure' && result.data && typeof result.data.message === 'string'
										? result.data.message
										: de.errors.generic;
								notify(message, 'error');
							};
						}}
					>
						<input type="hidden" name="cursor" value={nextCursor} />
						<input type="hidden" name="from" value={data.filters.fromIso} />
						<input type="hidden" name="to" value={data.filters.toIso} />
						{#if data.filters.deviceId}
							<input type="hidden" name="device_id" value={data.filters.deviceId} />
						{/if}
						{#if data.filters.userId}
							<input type="hidden" name="user_id" value={data.filters.userId} />
						{/if}
						{#if data.filters.minDurationMs !== undefined}
							<input type="hidden" name="min_duration_ms" value={data.filters.minDurationMs} />
						{/if}
						{#if data.filters.maxDurationMs !== undefined}
							<input type="hidden" name="max_duration_ms" value={data.filters.maxDurationMs} />
						{/if}
						<Button type="submit" variant="ghost" size="sm" disabled={loadingMore}>
							{loadingMore ? de.common.loading : de.pages.usage.loadMore}
						</Button>
					</form>
				{/if}
			{/if}
		</Card>

		{#if histogram.length > 0}
			<Card class="self-start">
				<CardHeader>
					<CardTitle>{de.pages.usage.duration}</CardTitle>
					<CardDescription>{de.pages.usage.histogramNote}</CardDescription>
				</CardHeader>
				<CardContent>
					<ul class="space-y-3">
						{#each histogram as bin (bin.lower)}
							<li>
								<div class="mb-1 flex justify-between text-xs">
									<span class="text-muted-foreground">
										{formatDurationMs(bin.lower)} – {bin.upper ? formatDurationMs(bin.upper) : '∞'}
									</span>
									<span class="font-medium tabular-nums">{bin.count}</span>
								</div>
								<div class="h-2 overflow-hidden rounded-full bg-muted">
									<div
										class="h-full rounded-full bg-linear-to-r from-primary/60 to-primary"
										style:width="{(bin.count / histogramMax) * 100}%"
									></div>
								</div>
							</li>
						{/each}
					</ul>
				</CardContent>
			</Card>
		{/if}
	</div>
</div>
