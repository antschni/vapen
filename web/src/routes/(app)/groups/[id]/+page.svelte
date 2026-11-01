<script lang="ts">
	import { resolve } from '$app/paths';
	import { Lock, Settings } from '@lucide/svelte';
	import LivePresenceGrid from '#lib/components/LivePresenceGrid.svelte';
	import LiveRefresh from '#lib/components/LiveRefresh.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import SegmentedNav from '#lib/components/SegmentedNav.svelte';
	import Avatar from '#lib/components/ui/avatar.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import { buttonVariants } from '#lib/components/ui/button-variants.js';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import { formatDurationMs, formatNumber } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
	import { roleLabel } from '#lib/roles.js';
	import { cn } from '#lib/utils.js';
	import type { PageData } from './$types';

	let { data }: { data: PageData & { elfbarBridgeLive: boolean } } = $props();

	const liveCards = $derived(data.elfbarBridgeLive);

	const ranges = [
		{ value: 'today', label: de.pages.groups.rangeToday },
		{ value: '7d', label: de.pages.groups.range7d },
		{ value: '30d', label: de.pages.groups.range30d }
	] as const;

	function rangeHref(r: 'today' | '7d' | '30d'): string {
		return `${resolve('/(app)/groups/[id]', { id: data.groupId })}?range=${r}`;
	}

	function hasUsage(member: PageData['overview']['members'][number]): boolean {
		return Boolean(member.visibility.usage_summary && member.usage && 'puff_count' in member.usage);
	}

	const leaderMax = $derived(
		data.overview.leaderboard.reduce((m, e) => Math.max(m, e.puff_count), 0) || 1
	);

	function rankClass(rank: number): string {
		if (rank === 1) return 'bg-amber-400/20 text-amber-700 dark:text-amber-300';
		if (rank === 2) return 'bg-slate-400/20 text-slate-700 dark:text-slate-300';
		if (rank === 3) return 'bg-orange-400/20 text-orange-700 dark:text-orange-300';
		return 'bg-muted text-muted-foreground';
	}
</script>

<svelte:head>
	<title>{data.groupName} · {de.pages.groups.title}</title>
</svelte:head>

<LiveRefresh active={liveCards} />

<PageHeader title={data.groupName} liveStats={liveCards} back={{ href: resolve('groups'), label: de.pages.groups.title }}>
	{#snippet actions()}
		{#if data.role === 'owner' || data.role === 'admin'}
			<a
				href={resolve('/(app)/groups/[id]/settings', { id: data.groupId })}
				class={buttonVariants({ variant: 'outline', size: 'sm' })}
			>
				<Settings />
				{de.pages.groups.settings}
			</a>
		{/if}
	{/snippet}
</PageHeader>

<div class="space-y-4">
	<Card>
		<CardHeader>
			<CardTitle>{de.pages.groups.liveGrid}</CardTitle>
		</CardHeader>
		<CardContent>
			<LivePresenceGrid groupId={data.groupId} />
		</CardContent>
	</Card>

	<div class="grid items-start gap-4 lg:grid-cols-5">
		<div class="lg:col-span-3">
			<Card animateLive={liveCards}>
				<CardHeader>
					<CardTitle>{de.pages.groups.leaderboard}</CardTitle>
					{#snippet actions()}
						<SegmentedNav
							size="sm"
							label={de.pages.groups.leaderboard}
							items={ranges.map((range) => ({
								href: rangeHref(range.value),
								label: range.label,
								active: data.range === range.value
							}))}
						/>
					{/snippet}
				</CardHeader>
				<CardContent>
					{#if data.overview.leaderboard.length === 0}
						<p class="py-8 text-center text-sm text-muted-foreground">{de.empty.noData}</p>
					{:else}
						<ol class="space-y-1">
							{#each data.overview.leaderboard as entry (entry.user_id)}
								<li class="flex items-center gap-3 rounded-xl px-2 py-2.5 transition-colors hover:bg-muted/50">
									<span
										class={cn(
											'flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-semibold tabular-nums',
											rankClass(entry.rank)
										)}
									>
										{entry.rank}
									</span>
									<Avatar name={entry.display_name} size="sm" />
									<div class="min-w-0 flex-1">
										<p class="truncate text-sm font-medium">{entry.display_name}</p>
										<div class="mt-1.5 h-1.5 overflow-hidden rounded-full bg-muted">
											<div
												class="h-full rounded-full bg-linear-to-r from-primary/60 to-primary"
												style:width="{(entry.puff_count / leaderMax) * 100}%"
											></div>
										</div>
									</div>
									<span class="w-24 shrink-0 text-right text-sm tabular-nums">
										<span class="font-medium">{formatNumber(entry.puff_count)}</span>
										<span class="text-muted-foreground"> Züge</span>
										<span class="block text-xs text-muted-foreground">{formatDurationMs(entry.total_duration_ms)}</span>
									</span>
								</li>
							{/each}
						</ol>
					{/if}
				</CardContent>
			</Card>
		</div>

		<Card class="lg:col-span-2">
			<CardHeader>
				<CardTitle>{de.pages.groups.members}</CardTitle>
			</CardHeader>
			<CardContent>
				<ul class="divide-y divide-border">
					{#each data.overview.members as member (member.user_id)}
						<li class="flex gap-3 py-3 first:pt-0 last:pb-0">
							<Avatar name={member.display_name} size="sm" class="mt-0.5" />
							<div class="min-w-0 flex-1 space-y-0.5">
								<div class="flex items-center gap-2">
									<p class="truncate text-sm font-medium">{member.display_name}</p>
									{#if member.role !== 'member'}
										<Badge variant="secondary">{roleLabel(member.role)}</Badge>
									{/if}
								</div>
								<p class="flex items-center gap-1 text-xs text-muted-foreground">
									{#if hasUsage(member)}
										{de.pages.groups.usageSummary}: {formatNumber(member.usage!.puff_count)} Züge · {formatDurationMs(
											member.usage!.total_duration_ms
										)}
									{:else if !member.visibility.usage_summary}
										<Lock class="size-3" />
										{de.pages.groups.usageSummary} {de.empty.private}
									{/if}
								</p>
								<p class="flex items-center gap-1 text-xs text-muted-foreground">
									{#if member.visibility.device_stats && member.device && 'model' in member.device}
										{de.pages.groups.deviceSummary}: {member.device.model}
										{#if member.device.battery_percent !== undefined}
											· {member.device.battery_percent} %
										{/if}
									{:else if !member.visibility.device_stats}
										<Lock class="size-3" />
										{de.pages.groups.deviceSummary} {de.empty.private}
									{/if}
								</p>
							</div>
						</li>
					{/each}
				</ul>
			</CardContent>
		</Card>
	</div>
</div>
