<script lang="ts">
	import { resolve } from '$app/paths';
	import { enhance } from '$app/forms';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import { de } from '#lib/i18n/de.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let displayName = $state('');
	let timezone = $state('Europe/Berlin');

	$effect(() => {
		displayName = data.profile?.display_name ?? '';
		timezone = data.profile?.timezone ?? 'Europe/Berlin';
	});
</script>

<svelte:head>
	<title>{de.pages.account.title} · {de.app.name}</title>
</svelte:head>

<h1 class="text-2xl font-bold tracking-tight">{de.pages.account.title}</h1>

{#if data.profile}
	<Card class="mt-6">
		<CardHeader>
			<CardTitle>{de.pages.account.profile}</CardTitle>
		</CardHeader>
		<CardContent>
			<form method="POST" action="?/profile" class="space-y-4" use:enhance>
				<div class="space-y-2">
					<Label for="display_name">{de.auth.displayName}</Label>
					<Input id="display_name" name="display_name" bind:value={displayName} required />
				</div>
				<div class="space-y-2">
					<Label for="timezone">{de.auth.timezone}</Label>
					<Input id="timezone" name="timezone" bind:value={timezone} required />
				</div>
				<p class="text-xs text-muted-foreground">{data.profile.email}</p>
				{#if form?.profileError}
					<p class="text-sm text-destructive">{form.profileError}</p>
				{/if}
				{#if form?.profileSaved}
					<p class="text-sm text-emerald-600">{de.pages.account.saved}</p>
				{/if}
				<Button type="submit">{de.common.save}</Button>
			</form>
		</CardContent>
	</Card>

	<Card class="mt-6">
		<CardHeader>
			<CardTitle>{de.pages.account.password}</CardTitle>
		</CardHeader>
		<CardContent>
			<form method="POST" action="?/password" class="space-y-4" use:enhance>
				<div class="space-y-2">
					<Label for="current_password">{de.pages.account.currentPassword}</Label>
					<Input id="current_password" name="current_password" type="password" required />
				</div>
				<div class="space-y-2">
					<Label for="new_password">{de.pages.account.newPassword}</Label>
					<Input id="new_password" name="new_password" type="password" required minlength={12} />
				</div>
				{#if form?.passwordError}
					<p class="text-sm text-destructive">{form.passwordError}</p>
				{/if}
				{#if form?.passwordSaved}
					<p class="text-sm text-emerald-600">{de.pages.account.passwordChanged}</p>
				{/if}
				<Button type="submit">{de.pages.account.password}</Button>
			</form>
		</CardContent>
	</Card>

	<Card class="mt-6">
		<CardHeader>
			<CardTitle>{de.pages.account.export}</CardTitle>
			<p class="text-sm text-muted-foreground">{de.pages.account.exportHint}</p>
		</CardHeader>
		<CardContent>
			<a
				href={resolve('settings/account/export')}
				class="inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/90"
			>
				{de.pages.account.export}
			</a>
		</CardContent>
	</Card>

	<Card class="mt-6 border-destructive/50">
		<CardHeader>
			<CardTitle>{de.pages.account.deleteAccount}</CardTitle>
			<p class="text-sm text-muted-foreground">{de.pages.account.deleteWarning}</p>
		</CardHeader>
		<CardContent>
			<form method="POST" action="?/delete" class="space-y-4" use:enhance>
				<div class="space-y-2">
					<Label for="delete_password">{de.auth.password}</Label>
					<Input id="delete_password" name="password" type="password" required />
				</div>
				{#if form?.deleteError}
					<p class="text-sm text-destructive">{form.deleteError}</p>
				{/if}
				<Button type="submit" variant="destructive">{de.pages.account.deleteConfirm}</Button>
			</form>
		</CardContent>
	</Card>
{/if}
