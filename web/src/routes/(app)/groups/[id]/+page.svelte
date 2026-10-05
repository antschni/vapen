<script lang="ts">
	import LivePresenceGrid from '#lib/components/LivePresenceGrid.svelte';
	import LiveRefresh from '#lib/components/LiveRefresh.svelte';
	import LiveStatsBadge from '#lib/components/LiveStatsBadge.svelte';
	import LiveStatsPulse from '#lib/components/LiveStatsPulse.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import { formatDurationMs, formatNumber } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
	import { resolve } from '$app/paths';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	function roleLabel(role: string): string {
		if (role === 'owner') return de.pages.groups.roleOwner;
		if (role === 'admin') return de.pages.groups.roleAdmin;
		return de.pages.groups.roleMember;
	}

	function rangeHref(r: 'today' | '7d' | '30d'): string {
		return `${resolve('/(app)/groups/[id]', { id: data.groupId })}?range=${r}`;
	}

	function hasUsage(member: PageData['overview']['members'][number]): boolean {
		return Boolean(
			member.visibility.usage_summary && member.usage && 'puff_count' in member.usage
		);
	}
</script>

<svelte:head>
	<title>{data.groupName} · {de.pages.groups.title}</title>
</svelte:head>

<LiveRefresh />

<div class="flex flex-wrap items-center justify-between gap-3">
	<div class="min-w-0 flex-1">
		<p class="text-sm text-muted-foreground"><a href={resolve('groups')} class="hover:underline">{de.common.back}</a></p>
		<h1 class="text-2xl font-bold tracking-tight">{data.groupName}</h1>
	</div>
	<div class="flex flex-wrap items-center gap-2">
		<LiveStatsBadge />
	{#if data.role === 'owner' || data.role === 'admin'}
		<a
			href={resolve('/(app)/groups/[id]/settings', { id: data.groupId })}
			class="inline-flex h-9 items-center justify-center rounded-md border border-input bg-background px-4 text-sm font-medium hover:bg-accent"
		>
			{de.pages.groups.settings}
		</a>
	{/if}
	</div>
</div>

<Card class="mt-6">
	<CardContent class="pt-6">
		<LivePresenceGrid groupId={data.groupId} />
	</CardContent>
</Card>

<LiveStatsPulse class="mt-6 block">
<Card>
	<CardHeader class="flex flex-row flex-wrap items-center justify-between gap-2">
		<CardTitle>{de.pages.groups.leaderboard}</CardTitle>
		<div class="flex gap-1">
			<a
				href={rangeHref('today')}
				class="rounded-md px-2 py-1 text-xs {data.range === 'today'
					? 'bg-accent'
					: 'text-muted-foreground hover:bg-accent/50'}"
			>
				{de.pages.groups.rangeToday}
			</a>
			<a
				href={rangeHref('7d')}
				class="rounded-md px-2 py-1 text-xs {data.range === '7d'
					? 'bg-accent'
					: 'text-muted-foreground hover:bg-accent/50'}"
			>
				{de.pages.groups.range7d}
			</a>
			<a
				href={rangeHref('30d')}
				class="rounded-md px-2 py-1 text-xs {data.range === '30d'
					? 'bg-accent'
					: 'text-muted-foreground hover:bg-accent/50'}"
			>
				{de.pages.groups.range30d}
			</a>
		</div>
	</CardHeader>
	<CardContent>
		{#if data.overview.leaderboard.length === 0}
			<p class="text-sm text-muted-foreground">{de.empty.noData}</p>
		{:else}
			<ol class="space-y-2">
				{#each data.overview.leaderboard as entry (entry.user_id)}
					<li class="flex items-center justify-between rounded border p-3 text-sm">
						<span>
							<span class="font-medium">#{entry.rank}</span>
							{entry.display_name}
						</span>
						<span class="text-muted-foreground">
							{formatNumber(entry.puff_count)} Züge · {formatDurationMs(entry.total_duration_ms)}
						</span>
					</li>
				{/each}
			</ol>
		{/if}
	</CardContent>
</Card>
</LiveStatsPulse>

<Card class="mt-6">
	<CardHeader>
		<CardTitle>{de.pages.groups.members}</CardTitle>
	</CardHeader>
	<CardContent class="space-y-4">
		{#each data.overview.members as member (member.user_id)}
			<div class="rounded-lg border p-4">
				<div class="flex flex-wrap items-center gap-2">
					<p class="font-medium">{member.display_name}</p>
					<Badge variant="secondary">{roleLabel(member.role)}</Badge>
				</div>
				{#if hasUsage(member)}
					<p class="mt-2 text-sm text-muted-foreground">
						{de.pages.groups.usageSummary}: {formatNumber((member.usage!).puff_count)} Züge · {formatDurationMs((member.usage!).total_duration_ms)}
					</p>
				{:else if !member.visibility.usage_summary}
					<p class="mt-2 text-sm text-muted-foreground">{de.empty.private}</p>
				{/if}
				{#if member.visibility.device_stats && member.device && 'model' in member.device}
					<p class="mt-1 text-sm text-muted-foreground">
						{de.pages.groups.deviceSummary}: {member.device.model}
						{#if member.device.battery_percent !== undefined}
							· {member.device.battery_percent} %
						{/if}
					</p>
				{:else if !member.visibility.device_stats}
					<p class="mt-1 text-sm text-muted-foreground">{de.empty.private}</p>
				{/if}
			</div>
		{/each}
	</CardContent>
</Card>
