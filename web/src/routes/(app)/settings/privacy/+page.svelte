<script lang="ts">
	import { enhance } from '$app/forms';
	import PrivacyTriState from '#lib/components/PrivacyTriState.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import { PRIVACY_FLAGS, formValueFromOverride, type PrivacyFlag } from '#lib/privacy.js';
	import { de } from '#lib/i18n/de.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let previewGroupId = $state('');

	$effect(() => {
		if (!previewGroupId && data.groupPrivacy[0]?.groupId) {
			previewGroupId = data.groupPrivacy[0].groupId;
		}
	});

	const preview = $derived(
		data.groupPrivacy.find((g) => g.groupId === previewGroupId)?.privacy?.effective ?? data.defaults
	);
	const previewName = $derived(
		data.groupPrivacy.find((g) => g.groupId === previewGroupId)?.groupName ?? ''
	);

	function flagLabel(flag: PrivacyFlag): string {
		return de.pages.privacy.flags[flag].label;
	}
</script>

<svelte:head>
	<title>{de.pages.privacy.title} · {de.app.name}</title>
</svelte:head>

<h1 class="text-2xl font-bold tracking-tight">{de.pages.privacy.title}</h1>

{#if form?.message}
	<p class="mt-4 text-sm text-destructive">{form.message}</p>
{/if}
{#if form?.saved}
	<p class="mt-4 text-sm text-emerald-600">{de.pages.account.saved}</p>
{/if}

<Card class="mt-6">
	<CardHeader>
		<CardTitle>{de.pages.privacy.defaults}</CardTitle>
		<p class="text-sm text-muted-foreground">{de.pages.privacy.defaultsHint}</p>
	</CardHeader>
	<CardContent>
		{#if data.defaults}
			<form method="POST" action="?/defaults" class="space-y-4" use:enhance>
				{#each PRIVACY_FLAGS as flag (flag)}
					<div class="flex items-center justify-between gap-4 rounded border p-3">
						<div>
							<Label for={`def-${flag}`}>{de.pages.privacy.flags[flag].label}</Label>
							<p class="text-xs text-muted-foreground">{de.pages.privacy.flags[flag].description}</p>
						</div>
						<input
							id={`def-${flag}`}
							type="checkbox"
							name={flag}
							checked={data.defaults[flag]}
							class="size-4"
						/>
					</div>
				{/each}
				<Button type="submit">{de.common.save}</Button>
			</form>
		{/if}
	</CardContent>
</Card>

{#each data.groupPrivacy as gp (gp.groupId)}
	{#if gp.privacy}
		<Card class="mt-6">
			<CardHeader>
				<CardTitle>{gp.groupName}</CardTitle>
			</CardHeader>
			<CardContent>
				<form method="POST" action="?/group" class="space-y-4" use:enhance>
					<input type="hidden" name="group_id" value={gp.groupId} />
					{#each PRIVACY_FLAGS as flag (flag)}
						<PrivacyTriState
							{flag}
							name={flag}
							value={formValueFromOverride(gp.privacy!.overrides[flag])}
						/>
					{/each}
					<Button type="submit">{de.common.save}</Button>
				</form>
			</CardContent>
		</Card>
	{/if}
{/each}

{#if preview && previewName}
	<Card class="mt-6">
		<CardHeader>
			<CardTitle>{de.pages.privacy.previewTitle(previewName)}</CardTitle>
		</CardHeader>
		<CardContent class="space-y-2 text-sm">
			<label class="flex items-center gap-2">
				<span class="text-muted-foreground">Gruppe für Vorschau:</span>
				<select
					class="rounded border px-2 py-1"
					bind:value={previewGroupId}
				>
					{#each data.groupPrivacy as gp (gp.groupId)}
						<option value={gp.groupId}>{gp.groupName}</option>
					{/each}
				</select>
			</label>
			<ul class="mt-3 space-y-1">
				{#each PRIVACY_FLAGS as flag (flag)}
					<li>
						{flagLabel(flag)}:
						{preview[flag] ? de.pages.privacy.on : de.pages.privacy.off}
					</li>
				{/each}
			</ul>
		</CardContent>
	</Card>
{/if}
