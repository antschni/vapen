<script lang="ts">
	import { resolve } from '$app/paths';
	import { enhance } from '$app/forms';
	import type { Snippet } from 'svelte';
	import { Download } from '@lucide/svelte';
	import Button from '#lib/components/ui/button.svelte';
	import { buttonVariants } from '#lib/components/ui/button-variants.js';
	import Card from '#lib/components/ui/card.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import { de } from '#lib/i18n/de.js';
	import { notify } from '#lib/notifications.svelte.js';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import { cn } from '#lib/utils.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let displayName = $derived(data.profile?.display_name ?? '');
</script>

{#snippet section(title: string, description: string, body: Snippet, danger = false)}
	<section class="grid gap-4 py-8 first:pt-0 md:grid-cols-[16rem_minmax(0,1fr)] md:gap-10">
		<div>
			<h2 class={cn('text-[15px] font-semibold', danger && 'text-destructive')}>{title}</h2>
			<p class="mt-1 text-sm text-muted-foreground">{description}</p>
		</div>
		<Card class={cn('p-5', danger && 'border-destructive/25')}>
			{@render body()}
		</Card>
	</section>
{/snippet}

<svelte:head>
	<title>{de.pages.account.title} · {de.app.name}</title>
</svelte:head>

<PageHeader title={de.pages.account.title} description={de.pages.account.subtitle} />

{#if data.profile}
	<div class="divide-y divide-border/70">
		{#snippet profileBody()}
			<form
				method="POST"
				action="?/profile"
				class="space-y-4"
				use:enhance={() => {
					return async ({ result, update }) => {
						await update({ reset: false });
						if (result.type === 'success') notify(de.pages.account.profileUpdated);
					};
				}}
			>
				<div class="space-y-1.5">
					<Label for="display_name">{de.auth.displayName}</Label>
					<Input id="display_name" name="display_name" bind:value={displayName} required />
				</div>
				<div class="space-y-1.5">
					<Label for="email">{de.auth.email}</Label>
					<Input id="email" value={data.profile?.email} disabled readonly />
				</div>
				{#if form?.profileError}
					<p class="text-sm text-destructive">{form.profileError}</p>
				{/if}
				<div class="flex justify-end">
					<Button type="submit">{de.common.save}</Button>
				</div>
			</form>
		{/snippet}
		{@render section(de.pages.account.profile, de.pages.account.profileHint, profileBody)}

		{#snippet passwordBody()}
			<form
				method="POST"
				action="?/password"
				class="space-y-4"
				use:enhance={() => {
					return async ({ result, update }) => {
						await update();
						if (result.type === 'success') notify(de.pages.account.passwordChanged);
					};
				}}
			>
				<div class="space-y-1.5">
					<Label for="current_password">{de.pages.account.currentPassword}</Label>
					<Input id="current_password" name="current_password" type="password" autocomplete="current-password" required />
				</div>
				<div class="space-y-1.5">
					<Label for="new_password">{de.pages.account.newPassword}</Label>
					<Input
						id="new_password"
						name="new_password"
						type="password"
						autocomplete="new-password"
						required
						minlength={12}
					/>
				</div>
				{#if form?.passwordError}
					<p class="text-sm text-destructive">{form.passwordError}</p>
				{/if}
				<div class="flex justify-end">
					<Button type="submit">{de.pages.account.password}</Button>
				</div>
			</form>
		{/snippet}
		{@render section(de.pages.account.password, de.pages.account.passwordHint, passwordBody)}

		{#snippet exportBody()}
			<a href={resolve('settings/account/export')} class={buttonVariants({ variant: 'outline' })}>
				<Download />
				{de.pages.account.export}
			</a>
		{/snippet}
		{@render section(de.pages.account.export, de.pages.account.exportHint, exportBody)}

		{#snippet deleteBody()}
			<form method="POST" action="?/delete" class="space-y-4" use:enhance>
				<div class="space-y-1.5">
					<Label for="delete_password">{de.auth.password}</Label>
					<Input id="delete_password" name="password" type="password" autocomplete="current-password" required />
				</div>
				{#if form?.deleteError}
					<p class="text-sm text-destructive">{form.deleteError}</p>
				{/if}
				<div class="flex justify-end">
					<Button type="submit" variant="destructive">{de.pages.account.deleteConfirm}</Button>
				</div>
			</form>
		{/snippet}
		{@render section(de.pages.account.deleteAccount, de.pages.account.deleteWarning, deleteBody, true)}
	</div>
{/if}
