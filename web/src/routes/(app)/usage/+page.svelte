<script lang="ts">
	import { format } from 'date-fns';
	import { de as dateFnsDe } from 'date-fns/locale';
	import { enhance } from '$app/forms';
	import BarSeriesChart from '$lib/components/charts/BarSeriesChart.svelte';
	import HeatmapChart from '$lib/components/charts/HeatmapChart.svelte';
	import Button from '$lib/components/ui/button.svelte';
	import Card from '$lib/components/ui/card.svelte';
	import CardContent from '$lib/components/ui/card-content.svelte';
	import CardHeader from '$lib/components/ui/card-header.svelte';
	import CardTitle from '$lib/components/ui/card-title.svelte';
	import Label from '$lib/components/ui/label.svelte';
	import { formatDurationMs, formatNumber } from '$lib/format';
	import { de } from '$lib/i18n/de';
	import type { components } from '$lib/api/schema.d.ts';
	import type { PageData, ActionData } from './$types';

	type Puff = components['schemas']['Puff'];

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let extraPuffs = $state<Puff[]>([]);
	let nextCursor = $state<string | null>(null);
	let loadingMore = $state(false);

	$effect(() => {
		extraPuffs = [];
		nextCursor = data.puffNextCursor;
	});

	const allPuffs = $derived([...data.puffs, ...extraPuffs]);

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
		const q = new URLSearchParams();
		q.set('preset', data.filters.preset);
		q.set('bucket', data.filters.bucket);
		if (data.filters.deviceId) q.set('device_id', data.filters.deviceId);
		if (data.filters.userId) q.set('user_id', data.filters.userId);
		if (data.filters.preset === 'custom') {
			q.set('from', data.filters.fromIso);
			q.set('to', data.filters.toIso);
		}
		return `/usage/export.csv?${q}`;
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
</script>

<svelte:head>
	<title>{de.pages.usage.title} · {de.app.name}</title>
</svelte:head>

<h1 class="text-2xl font-bold tracking-tight">{de.pages.usage.title}</h1>

<Card class="mt-6">
	<CardHeader>
		<CardTitle>{de.pages.usage.filters}</CardTitle>
	</CardHeader>
	<CardContent>
		<form method="GET" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
			<div class="space-y-2">
				<Label for="preset">{de.pages.usage.preset}</Label>
				<select
					id="preset"
					name="preset"
					class="flex h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
				>
					<option value="today" selected={data.filters.preset === 'today'}>{de.pages.usage.presetToday}</option>
					<option value="7d" selected={data.filters.preset === '7d'}>{de.pages.usage.preset7d}</option>
					<option value="30d" selected={data.filters.preset === '30d'}>{de.pages.usage.preset30d}</option>
					<option value="90d" selected={data.filters.preset === '90d'}>{de.pages.usage.preset90d}</option>
					<option value="year" selected={data.filters.preset === 'year'}>{de.pages.usage.presetYear}</option>
				</select>
			</div>
			<div class="space-y-2">
				<Label for="bucket">{de.pages.usage.bucket}</Label>
				<select
					id="bucket"
					name="bucket"
					class="flex h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
				>
					<option value="hour" selected={data.filters.bucket === 'hour'}>{de.pages.usage.bucketHour}</option>
					<option value="day" selected={data.filters.bucket === 'day'}>{de.pages.usage.bucketDay}</option>
					<option value="week" selected={data.filters.bucket === 'week'}>{de.pages.usage.bucketWeek}</option>
					<option value="month" selected={data.filters.bucket === 'month'}>{de.pages.usage.bucketMonth}</option>
				</select>
			</div>
			<div class="space-y-2">
				<Label for="device_id">{de.pages.usage.device}</Label>
				<select
					id="device_id"
					name="device_id"
					class="flex h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
				>
					<option value="">{de.pages.usage.deviceAll}</option>
					{#each data.devices as device (device.id)}
						<option value={device.id} selected={data.filters.deviceId === device.id}>{device.name}</option>
					{/each}
				</select>
			</div>
			<div class="space-y-2">
				<Label for="user_id">{de.pages.usage.person}</Label>
				<select
					id="user_id"
					name="user_id"
					class="flex h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
				>
					<option value="">{de.pages.usage.personSelf}</option>
					{#each data.detailMembers as member (member.id)}
						<option value={member.id} selected={data.filters.userId === member.id}>{member.name}</option>
					{/each}
				</select>
			</div>
			<div class="sm:col-span-2 lg:col-span-4 flex flex-wrap gap-2">
				<Button type="submit">{de.pages.usage.applyFilters}</Button>
				<a
					href={exportHref}
					class="inline-flex h-9 items-center justify-center rounded-md border border-input bg-background px-4 text-sm font-medium hover:bg-accent"
				>
					{de.pages.usage.exportCsv}
				</a>
			</div>
		</form>
	</CardContent>
</Card>

{#if data.stats}
	<div class="mt-6 grid gap-4 sm:grid-cols-2">
		<Card>
			<CardHeader>
				<CardTitle>{de.pages.usage.comparePrevious}</CardTitle>
			</CardHeader>
			<CardContent class="text-sm">
				<p>
					{de.pages.usage.puffsDelta}:
					{puffDelta !== null ? `${puffDelta >= 0 ? '+' : ''}${formatNumber(puffDelta)}` : '—'}
				</p>
				<p class="mt-1">
					{de.pages.usage.durationDelta}:
					{durationDelta !== null
						? `${durationDelta >= 0 ? '+' : ''}${formatDurationMs(Math.abs(durationDelta))}`
						: '—'}
				</p>
			</CardContent>
		</Card>
	</div>
{/if}

<div class="mt-6 grid gap-6 lg:grid-cols-2">
	<Card>
		<CardHeader>
			<CardTitle>{de.pages.usage.chartSeries}</CardTitle>
		</CardHeader>
		<CardContent>
			{#if chartPoints.length === 0}
				<p class="text-sm text-muted-foreground">{de.empty.noData}</p>
			{:else}
				<BarSeriesChart points={chartPoints} ariaLabel={de.pages.usage.chartSeries} />
			{/if}
		</CardContent>
	</Card>
	<Card>
		<CardHeader>
			<CardTitle>{de.pages.usage.chartHeatmap}</CardTitle>
		</CardHeader>
		<CardContent>
			{#if data.heatmap.length === 0}
				<p class="text-sm text-muted-foreground">{de.empty.noData}</p>
			{:else}
				<HeatmapChart cells={data.heatmap} ariaLabel={de.pages.usage.chartHeatmap} />
			{/if}
		</CardContent>
	</Card>
</div>

<Card class="mt-6">
	<CardHeader>
		<CardTitle>{de.pages.usage.puffTable}</CardTitle>
	</CardHeader>
	<CardContent>
		{#if allPuffs.length === 0}
			<p class="text-sm text-muted-foreground">{de.pages.usage.noPuffs}</p>
		{:else}
			<div class="overflow-x-auto">
				<table class="w-full text-sm">
					<thead>
						<tr class="border-b text-left text-muted-foreground">
							<th class="pb-2 pr-4">{de.pages.usage.startedAt}</th>
							<th class="pb-2 pr-4">{de.pages.usage.duration}</th>
							<th class="pb-2">{de.pages.usage.source}</th>
						</tr>
					</thead>
					<tbody>
						{#each allPuffs as puff (puff.id)}
							<tr class="border-b border-border/50">
								<td class="py-2 pr-4">
									{format(new Date(puff.started_at), 'dd.MM.yyyy HH:mm:ss', { locale: dateFnsDe })}
								</td>
								<td class="py-2 pr-4">{formatDurationMs(puff.duration_ms)}</td>
								<td class="py-2">
									{puff.source === 'live' ? de.pages.usage.sourceLive : de.pages.usage.sourceHistory}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			{#if histogram.length > 0}
				<p class="mt-4 text-xs text-muted-foreground">{de.pages.usage.histogramNote}</p>
				<ul class="mt-2 space-y-1 text-xs">
					{#each histogram as bin}
						<li>{formatDurationMs(bin.lower)} – {bin.upper ? formatDurationMs(bin.upper) : '∞'}: {bin.count}</li>
					{/each}
				</ul>
			{/if}
			{#if nextCursor}
				<form
					method="POST"
					action="?/loadMore"
					class="mt-4"
					use:enhance={() => {
						loadingMore = true;
						return async ({ result, update }) => {
							loadingMore = false;
							if (result.type === 'success' && result.data) {
								const d = result.data as { items: Puff[]; next_cursor: string | null };
								extraPuffs = [...extraPuffs, ...d.items];
								nextCursor = d.next_cursor;
							} else {
								await update();
							}
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
					<Button type="submit" variant="outline" disabled={loadingMore}>{de.pages.usage.loadMore}</Button>
				</form>
			{/if}
		{/if}
	</CardContent>
</Card>
