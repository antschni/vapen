<script lang="ts">
	import { resolve } from '$app/paths';
	import { ArrowUpRight, Smartphone } from '@lucide/svelte';
	import BatteryMeter from '#lib/components/BatteryMeter.svelte';
	import EmptyState from '#lib/components/EmptyState.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import { formatRelativeTime } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();
</script>

<svelte:head>
	<title>{de.pages.devices.title} · {de.app.name}</title>
</svelte:head>

<PageHeader title={de.pages.devices.title} />

{#if data.devices.length === 0}
	<EmptyState icon={Smartphone} title={de.pages.devices.empty} description={de.empty.noData} />
{:else}
	<div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
		{#each data.devices as device (device.id)}
			{@const battery = device.latest_status?.battery_percent}
			<a
				href={resolve('/(app)/devices/[id]', { id: device.id })}
				class="group rounded-2xl outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30"
			>
				<Card class="flex h-full flex-col p-5 transition-shadow group-hover:shadow-raised">
					<div class="flex items-start justify-between gap-3">
						<span class="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-primary/10 text-primary">
							<Smartphone class="size-5" />
						</span>
						<span
							class="flex size-8 items-center justify-center rounded-full text-muted-foreground transition-colors group-hover:bg-accent group-hover:text-foreground"
						>
							<ArrowUpRight class="size-4" />
						</span>
					</div>
					<div class="mt-4 min-w-0">
						<p class="truncate text-base font-semibold tracking-tight">{device.name}</p>
						<p class="truncate text-sm text-muted-foreground">{device.model}</p>
					</div>

					{#if battery !== undefined}
						<div class="mt-5">
							<div class="mb-2 flex items-baseline justify-between text-xs">
								<span class="text-muted-foreground">{de.pages.devices.battery}</span>
								<span class="text-sm font-semibold tabular-nums">{battery} %</span>
							</div>
							<BatteryMeter percent={battery} />
						</div>
					{/if}

					{#if device.last_seen_at}
						<p class="mt-auto pt-4 text-xs text-muted-foreground">
							{de.pages.devices.lastSeen}
							{formatRelativeTime(device.last_seen_at)}
						</p>
					{/if}
				</Card>
			</a>
		{/each}
	</div>
{/if}
