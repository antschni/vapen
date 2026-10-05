<script lang="ts">
	import { resolve } from '$app/paths';
	import { ChevronRight, Smartphone } from '@lucide/svelte';
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
				class="group rounded-xl outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30"
			>
				<Card class="h-full p-5 transition-[border-color,box-shadow] group-hover:border-border group-hover:shadow-raised">
					<div class="flex items-start gap-3">
						<span class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/[0.08] text-primary">
							<Smartphone class="size-5" />
						</span>
						<div class="min-w-0 flex-1">
							<p class="truncate font-medium">{device.name}</p>
							<p class="truncate text-xs text-muted-foreground">{device.model}</p>
						</div>
						<ChevronRight
							class="size-4 shrink-0 text-muted-foreground/60 transition-transform group-hover:translate-x-0.5 group-hover:text-foreground"
						/>
					</div>

					{#if battery !== undefined}
						<div class="mt-5">
							<div class="mb-1.5 flex justify-between text-xs">
								<span class="text-muted-foreground">{de.pages.devices.battery}</span>
								<span class="font-medium tabular-nums">{battery} %</span>
							</div>
							<div class="h-1.5 overflow-hidden rounded-full bg-muted">
								<div
									class={[
										'h-full rounded-full',
										battery <= 15 ? 'bg-destructive' : battery <= 35 ? 'bg-amber-500' : 'bg-emerald-500'
									]}
									style:width="{battery}%"
								></div>
							</div>
						</div>
					{/if}

					{#if device.last_seen_at}
						<p class="mt-4 text-xs text-muted-foreground">
							{de.pages.devices.lastSeen}
							{formatRelativeTime(device.last_seen_at)}
						</p>
					{/if}
				</Card>
			</a>
		{/each}
	</div>
{/if}
