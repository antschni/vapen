<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import { format } from 'date-fns';
	import { de as dateFnsDe } from 'date-fns/locale';
	import { BatteryCharging, Copy, Gauge, KeyRound, Timer, TrendingUp } from '@lucide/svelte';
	import BarSeriesChart from '#lib/components/charts/BarSeriesChart.svelte';
	import KpiCard from '#lib/components/KpiCard.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardDescription from '#lib/components/ui/card-description.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import { formatDurationMs, formatNumber, formatRelativeTime } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
	import { notify } from '#lib/notifications.svelte.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let tokenPlain = $state<string | null>(null);

	$effect(() => {
		if (form?.newToken?.token) {
			tokenPlain = form.newToken.token;
		}
	});

	const batteryPoints = $derived(
		data.stats?.battery_series.map((s) => ({
			label: format(new Date(s.bucket_start), 'dd.MM. HH:mm', { locale: dateFnsDe }),
			durationMs: s.battery_percent ?? 0,
			puffCount: 0
		})) ?? []
	);

	async function copyToken() {
		if (!tokenPlain) return;
		await navigator.clipboard.writeText(tokenPlain);
		notify(de.common.copied);
	}
</script>

<svelte:head><title>{data.device.name} · {de.pages.devices.title}</title></svelte:head>

<PageHeader
	title={data.device.name}
	description={data.device.model}
	back={{ href: resolve('devices'), label: de.pages.devices.title }}
/>

<div class="space-y-6">
	{#if data.stats}
		<div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
			<KpiCard
				icon={BatteryCharging}
				title={de.pages.devices.puffsSinceCharge}
				value={formatNumber(data.stats.puffs_since_last_charge)}
			/>
			<KpiCard
				icon={Timer}
				title={de.pages.devices.avgDuration}
				value={formatDurationMs(data.stats.puff_duration.avg_ms)}
			/>
			<KpiCard
				icon={Gauge}
				title={de.pages.devices.median}
				value={formatDurationMs(data.stats.puff_duration.median_ms)}
			/>
			<KpiCard
				icon={TrendingUp}
				title={de.pages.devices.p90}
				value={formatDurationMs(data.stats.puff_duration.p90_ms)}
			/>
		</div>

		<Card>
			<CardHeader>
				<CardTitle>{de.pages.devices.statsBattery}</CardTitle>
			</CardHeader>
			<CardContent>
				{#if batteryPoints.length > 0}
					<BarSeriesChart
						points={batteryPoints}
						ariaLabel={de.pages.devices.statsBattery}
						formatValue={(point) => `${point.durationMs} %`}
					/>
				{:else}
					<p class="py-12 text-center text-sm text-muted-foreground">{de.empty.noData}</p>
				{/if}
			</CardContent>
		</Card>
	{/if}

	<div class="grid gap-4 lg:grid-cols-5">
		<Card class="self-start lg:col-span-2">
			<CardHeader>
				<CardTitle>{de.pages.devices.rename}</CardTitle>
			</CardHeader>
			<CardContent>
				<form method="POST" action="?/rename" class="flex gap-2" use:enhance>
					<Input name="name" value={data.device.name} required aria-label={de.pages.devices.rename} />
					<Button type="submit">{de.common.save}</Button>
				</form>
				{#if form?.renameError}
					<p class="mt-2 text-sm text-destructive">{form.renameError}</p>
				{/if}
			</CardContent>
		</Card>

		<Card class="lg:col-span-3">
			<CardHeader>
				<CardTitle>{de.pages.devices.ingestTokens}</CardTitle>
				<CardDescription>{de.pages.devices.tokensHint}</CardDescription>
			</CardHeader>
			<CardContent class="space-y-4">
				<form method="POST" action="?/createToken" class="flex gap-2" use:enhance>
					<Input name="name" placeholder={de.pages.devices.tokenName} required aria-label={de.pages.devices.tokenName} />
					<Button type="submit" variant="outline">{de.pages.devices.createToken}</Button>
				</form>

				{#if tokenPlain}
					<div class="rounded-lg border border-amber-500/30 bg-amber-500/[0.06] p-3.5">
						<p class="text-sm text-amber-800 dark:text-amber-200">{de.pages.devices.tokenCreatedWarning}</p>
						<div class="mt-3 flex items-center gap-2">
							<code class="min-w-0 flex-1 truncate rounded-md bg-background px-2.5 py-1.5 font-mono text-xs">
								{tokenPlain}
							</code>
							<Button type="button" size="sm" variant="outline" onclick={copyToken}>
								<Copy />
								{de.pages.devices.copyToken}
							</Button>
						</div>
					</div>
				{/if}

				{#if data.tokens.length === 0}
					<p class="py-4 text-center text-sm text-muted-foreground">{de.pages.devices.noTokens}</p>
				{:else}
					<ul class="divide-y divide-border/60 rounded-lg border border-border/70">
						{#each data.tokens as token (token.id)}
							<li class="flex items-center gap-3 px-3.5 py-2.5">
								<KeyRound class="size-4 shrink-0 text-muted-foreground" />
								<div class="min-w-0 flex-1">
									<p class={['truncate text-sm font-medium', token.revoked_at && 'text-muted-foreground line-through']}>
										{token.name}
									</p>
									<p class="text-xs text-muted-foreground">
										{token.last_used_at
											? `${de.pages.devices.lastUsed} ${formatRelativeTime(token.last_used_at)}`
											: de.pages.devices.neverUsed}
									</p>
								</div>
								{#if token.revoked_at}
									<Badge variant="secondary">{de.pages.devices.tokenRevoked}</Badge>
								{:else}
									<form method="POST" action="?/revokeToken" use:enhance>
										<input type="hidden" name="token_id" value={token.id} />
										<Button type="submit" variant="destructive-ghost" size="sm">{de.pages.devices.revokeToken}</Button>
									</form>
								{/if}
							</li>
						{/each}
					</ul>
				{/if}
			</CardContent>
		</Card>
	</div>

	<Card class="border-destructive/25">
		<div class="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
			<div>
				<p class="text-[15px] font-semibold">{de.common.dangerZone}</p>
				<p class="mt-1 text-sm text-muted-foreground">{de.pages.devices.deleteConfirm}</p>
			</div>
			<form method="POST" action="?/delete" use:enhance>
				<Button type="submit" variant="destructive">{de.pages.devices.delete}</Button>
			</form>
		</div>
	</Card>
</div>
