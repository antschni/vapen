<script lang="ts">
	import { deserialize } from '$app/forms';
	import { refreshAll } from '$app/navigation';
	import PrivacyTriState from '#lib/components/PrivacyTriState.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import { PRIVACY_FLAGS, formValueFromOverride, type PrivacyFlag } from '#lib/privacy.js';
	import { de } from '#lib/i18n/de.js';
	import { notify } from '#lib/notifications.svelte.js';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	type TriValue = 'inherit' | 'on' | 'off';

	let previewGroupId = $state('');
	let defaultFlags = $state<Record<PrivacyFlag, boolean> | null>(null);
	let groupFlagValues = $state<Record<string, Record<PrivacyFlag, TriValue>>>({});

	function flagsFromDefaults(source: NonNullable<PageData['defaults']>): Record<PrivacyFlag, boolean> {
		return Object.fromEntries(PRIVACY_FLAGS.map((flag) => [flag, source[flag]])) as Record<
			PrivacyFlag,
			boolean
		>;
	}

	function overridesFromGroup(
		overrides: NonNullable<(typeof data.groupPrivacy)[number]['privacy']>['overrides']
	): Record<PrivacyFlag, TriValue> {
		return Object.fromEntries(
			PRIVACY_FLAGS.map((flag) => [flag, formValueFromOverride(overrides[flag])])
		) as Record<PrivacyFlag, TriValue>;
	}

	$effect(() => {
		if (data.defaults) {
			defaultFlags = flagsFromDefaults(data.defaults);
		}
	});

	$effect(() => {
		const next: Record<string, Record<PrivacyFlag, TriValue>> = {};
		for (const gp of data.groupPrivacy) {
			if (gp.privacy) {
				next[gp.groupId] = overridesFromGroup(gp.privacy.overrides);
			}
		}
		groupFlagValues = next;
	});

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

	let saveChain = Promise.resolve();

	function saveForm(form: HTMLFormElement | null) {
		if (!form) return;
		const body = new FormData(form);
		const action = form.action;
		saveChain = saveChain
			.then(async () => {
				const response = await fetch(action, {
					method: 'POST',
					body,
					headers: {
						accept: 'application/json',
						'x-sveltekit-action': 'true'
					}
				});
				const result = deserialize(await response.text());
				if (result.type === 'success') {
					notify(de.pages.privacy.applied);
					await refreshAll();
					return;
				}
				const message =
					result.type === 'failure' && result.data && typeof result.data.message === 'string'
						? result.data.message
						: de.errors.generic;
				notify(message, 'error');
				await refreshAll();
			})
			.catch(() => {
				notify(de.errors.network, 'error');
			});
	}
</script>

<svelte:head>
	<title>{de.pages.privacy.title} · {de.app.name}</title>
</svelte:head>

<PageHeader title={de.pages.privacy.title} description={de.pages.privacy.defaultsHint} />

<Card class="mt-6">
	<CardHeader>
		<CardTitle>{de.pages.privacy.defaults}</CardTitle>
		<p class="text-sm text-muted-foreground">{de.pages.privacy.defaultsHint}</p>
	</CardHeader>
	<CardContent>
		{#if data.defaults && defaultFlags}
			<form
				method="POST"
				action="?/defaults"
				class="space-y-4"
				onchange={(event) => saveForm(event.currentTarget)}
			>
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
							bind:checked={defaultFlags[flag]}
							class="size-4"
						/>
					</div>
				{/each}
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
				<form
					method="POST"
					action="?/group"
					class="space-y-4"
					onchange={(event) => saveForm(event.currentTarget)}
				>
					<input type="hidden" name="group_id" value={gp.groupId} />
					{#each PRIVACY_FLAGS as flag (flag)}
						{#if groupFlagValues[gp.groupId]}
							<PrivacyTriState {flag} name={flag} bind:value={groupFlagValues[gp.groupId][flag]} />
						{/if}
					{/each}
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
