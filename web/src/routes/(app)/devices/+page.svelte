<script lang="ts">
	import EmptyState from '$lib/components/EmptyState.svelte';
	import Badge from '$lib/components/ui/badge.svelte';
	import Card from '$lib/components/ui/card.svelte';
	import CardContent from '$lib/components/ui/card-content.svelte';
	import { formatRelativeTime } from '$lib/format';
	import { de } from '$lib/i18n/de';
	import { resolve } from '$app/paths';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();
</script>

<svelte:head>
	<title>{de.pages.devices.title} · {de.app.name}</title>
</svelte:head>

<h1 class="text-2xl font-bold tracking-tight">{de.pages.devices.title}</h1>

{#if data.devices.length === 0}
	<div class="mt-6">
		<EmptyState title={de.pages.devices.empty} description={de.empty.noData} />
	</div>
{:else}
	<div class="mt-6 grid gap-4 sm:grid-cols-2">
		{#each data.devices as device (device.id)}
			<a href={resolve('/(app)/devices/[id]', { id: device.id })} class="block">
				<Card class="transition-colors hover:bg-accent/30">
					<CardContent class="pt-6">
						<div class="flex items-start justify-between gap-2">
							<div>
								<p class="font-semibold">{device.name}</p>
								<p class="text-xs text-muted-foreground">{device.model}</p>
							</div>
							{#if device.latest_status?.battery_percent !== undefined}
								<Badge variant="secondary">
									{de.pages.devices.battery}: {device.latest_status.battery_percent} %
								</Badge>
							{/if}
						</div>
						{#if device.last_seen_at}
							<p class="mt-2 text-xs text-muted-foreground">
								{de.pages.devices.lastSeen}
								{formatRelativeTime(device.last_seen_at)}
							</p>
						{/if}
						<p class="mt-3 text-sm text-primary">{de.pages.devices.viewDetail} →</p>
					</CardContent>
				</Card>
			</a>
		{/each}
	</div>
{/if}
