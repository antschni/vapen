<script lang="ts">
	import { enhance } from '$app/forms';
	import BarSeriesChart from '#lib/components/charts/BarSeriesChart.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import { resolve } from '$app/paths';
	import { formatDurationMs, formatNumber } from '#lib/format.js';
	import { de } from '#lib/i18n/de.js';
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
			label: s.bucket_start,
			durationMs: s.battery_percent ?? 0,
			puffCount: 0
		})) ?? []
	);

	async function copyToken() {
		if (tokenPlain) await navigator.clipboard.writeText(tokenPlain);
	}
</script>

<svelte:head><title>{data.device.name} · {de.pages.devices.title}</title></svelte:head>
<p class="text-sm text-muted-foreground"><a href={resolve('devices')} class="hover:underline">{de.common.back}</a></p>
<h1 class="mt-2 text-2xl font-bold tracking-tight">{data.device.name}</h1>

<div class="mt-6 grid gap-6 lg:grid-cols-2">
	<Card>
		<CardHeader>
			<CardTitle>{de.pages.devices.rename}</CardTitle>
		</CardHeader>
		<CardContent>
			<form method="POST" action="?/rename" class="flex gap-2" use:enhance>
				<Input name="name" value={data.device.name} required />
				<Button type="submit">{de.common.save}</Button>
			</form>
			{#if form?.renameError}
				<p class="mt-2 text-sm text-destructive">{form.renameError}</p>
			{/if}
		</CardContent>
	</Card>

	<Card>
		<CardHeader>
			<CardTitle>{de.pages.devices.ingestTokens}</CardTitle>
		</CardHeader>
		<CardContent class="space-y-4">
			<form method="POST" action="?/createToken" class="flex gap-2" use:enhance>
				<Input name="name" placeholder={de.pages.devices.tokenName} required />
				<Button type="submit">{de.pages.devices.createToken}</Button>
			</form>
			{#if tokenPlain}
				<div class="rounded-md border border-amber-500/50 bg-amber-500/10 p-3 text-sm">
					<p>{de.pages.devices.tokenCreatedWarning}</p>
					<code class="mt-2 block break-all font-mono text-xs">{tokenPlain}</code>
					<Button type="button" size="sm" class="mt-2" onclick={copyToken}>
						{de.pages.devices.copyToken}
					</Button>
				</div>
			{/if}
			<ul class="space-y-2 text-sm">
				{#each data.tokens as token (token.id)}
					<li class="flex items-center justify-between gap-2 rounded border p-2">
						<span>
							{token.name}
							{#if token.revoked_at}
								<Badge variant="secondary" class="ml-2">{de.pages.devices.tokenRevoked}</Badge>
							{/if}
						</span>
						{#if !token.revoked_at}
							<form method="POST" action="?/revokeToken" use:enhance>
								<input type="hidden" name="token_id" value={token.id} />
								<Button type="submit" variant="outline" size="sm">{de.pages.devices.revokeToken}</Button>
							</form>
						{/if}
					</li>
				{/each}
			</ul>
		</CardContent>
	</Card>
</div>

{#if data.stats}
	<Card class="mt-6">
		<CardHeader>
			<CardTitle>{de.pages.devices.statsBattery}</CardTitle>
		</CardHeader>
		<CardContent>
			{#if batteryPoints.length > 0}
				<BarSeriesChart points={batteryPoints} ariaLabel={de.pages.devices.statsBattery} />
			{:else}
				<p class="text-sm text-muted-foreground">{de.empty.noData}</p>
			{/if}
			<p class="mt-4 text-sm">
				{de.pages.devices.puffsSinceCharge}: {formatNumber(data.stats.puffs_since_last_charge)}
			</p>
			<p class="text-sm text-muted-foreground">
				{de.pages.devices.durationStats}: {formatDurationMs(data.stats.puff_duration.avg_ms)} ({de.pages.devices.median}
				{formatDurationMs(data.stats.puff_duration.median_ms)}, {de.pages.devices.p90}
				{formatDurationMs(data.stats.puff_duration.p90_ms)})
			</p>
		</CardContent>
	</Card>
{/if}

<Card class="mt-6 border-destructive/50">
	<CardContent class="pt-6">
		<p class="text-sm text-muted-foreground">{de.pages.devices.deleteConfirm}</p>
		<form method="POST" action="?/delete" class="mt-3" use:enhance>
			<Button type="submit" variant="destructive">{de.pages.devices.delete}</Button>
		</form>
	</CardContent>
</Card>
