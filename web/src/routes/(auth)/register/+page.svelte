<script lang="ts">
	import { resolve } from '$app/paths';
	import { enhance } from '$app/forms';
	import { browser } from '$app/env';
	import { CircleAlert } from '@lucide/svelte';
	import { readBrowserTimezone } from '#lib/browser-timezone.js';
	import { de } from '#lib/i18n/de.js';
	import Button from '#lib/components/ui/button.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardDescription from '#lib/components/ui/card-description.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import type { PageData } from './$types';
	import type { AuthFormState } from '#lib/types/form.js';

	let { data, form }: { data: PageData; form?: AuthFormState } = $props();

	let email = $state('');
	let password = $state('');
	let display_name = $state('');
	let timezone = $state('UTC');

	$effect(() => {
		if (browser) timezone = readBrowserTimezone();
	});
</script>

<Card class="shadow-raised">
	<CardHeader class="pt-6">
		<CardTitle class="text-lg">{de.auth.register}</CardTitle>
		<CardDescription>{de.auth.registerSubtitle}</CardDescription>
	</CardHeader>
	<CardContent class="pb-6">
		<form
			method="POST"
			class="space-y-4"
			use:enhance={() => {
				timezone = readBrowserTimezone();
				return async ({ update }) => {
					await update();
				};
			}}
		>
			<input type="hidden" name="timezone" value={timezone} />
			{#if data.redirectTo}
				<input type="hidden" name="redirectTo" value={data.redirectTo} />
			{/if}
			{#if form?.message}
				<p
					class="flex items-center gap-2 rounded-lg bg-destructive/[0.08] px-3 py-2 text-sm text-destructive"
					role="alert"
				>
					<CircleAlert class="size-4 shrink-0" />
					{form.message}
				</p>
			{/if}
			<div class="space-y-1.5">
				<Label for="email">{de.auth.email}</Label>
				<Input
					id="email"
					name="email"
					type="email"
					autocomplete="email"
					required
					bind:value={email}
					aria-invalid={form?.fieldErrors?.email ? true : undefined}
				/>
				{#if form?.fieldErrors?.email}
					<p class="text-xs text-destructive">{form.fieldErrors.email[0]}</p>
				{/if}
			</div>
			<div class="space-y-1.5">
				<Label for="display_name">{de.auth.displayName}</Label>
				<Input
					id="display_name"
					name="display_name"
					type="text"
					autocomplete="nickname"
					required
					minlength={2}
					maxlength={40}
					bind:value={display_name}
					aria-invalid={form?.fieldErrors?.display_name ? true : undefined}
				/>
				{#if form?.fieldErrors?.display_name}
					<p class="text-xs text-destructive">{form.fieldErrors.display_name[0]}</p>
				{/if}
			</div>
			<div class="space-y-1.5">
				<Label for="password">{de.auth.password}</Label>
				<Input
					id="password"
					name="password"
					type="password"
					autocomplete="new-password"
					required
					minlength={12}
					maxlength={128}
					bind:value={password}
					aria-invalid={form?.fieldErrors?.password ? true : undefined}
				/>
				{#if form?.fieldErrors?.password}
					<p class="text-xs text-destructive">{form.fieldErrors.password[0]}</p>
				{:else}
					<p class="text-xs text-muted-foreground">{de.validation.passwordMin}</p>
				{/if}
			</div>
			<Button type="submit" class="w-full">{de.auth.submitRegister}</Button>
		</form>
	</CardContent>
</Card>

<p class="mt-6 text-center text-sm text-muted-foreground">
	{de.auth.hasAccount}
	<a class="font-medium text-primary underline-offset-4 hover:underline" href={resolve('login')}>{de.auth.login}</a>
</p>
