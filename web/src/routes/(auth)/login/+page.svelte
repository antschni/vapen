<script lang="ts">
	import { resolve } from '$app/paths';
	import { enhance } from '$app/forms';
	import { de } from '$lib/i18n/de';
	import Button from '$lib/components/ui/button.svelte';
	import Input from '$lib/components/ui/input.svelte';
	import Label from '$lib/components/ui/label.svelte';
	import Card from '$lib/components/ui/card.svelte';
	import CardHeader from '$lib/components/ui/card-header.svelte';
	import CardTitle from '$lib/components/ui/card-title.svelte';
	import CardContent from '$lib/components/ui/card-content.svelte';
	import type { PageData } from './$types';
	import type { AuthFormState } from '$lib/types/form';

	let { data, form }: { data: PageData; form?: AuthFormState } = $props();

	let email = $state('');
	let password = $state('');
</script>

<Card>
	<CardHeader>
		<CardTitle>{de.auth.login}</CardTitle>
		<p class="text-sm text-muted-foreground">{de.auth.loginSubtitle}</p>
	</CardHeader>
	<CardContent>
		<form method="POST" class="space-y-4" use:enhance>
			{#if data.redirectTo}
				<input type="hidden" name="redirectTo" value={data.redirectTo} />
			{/if}
			{#if form?.message}
				<p class="text-sm text-destructive" role="alert">{form.message}</p>
			{/if}
			<div class="space-y-2">
				<Label for="email">{de.auth.email}</Label>
				<Input id="email" name="email" type="email" autocomplete="email" required bind:value={email} />
				{#if form?.fieldErrors?.email}
					<p class="text-xs text-destructive">{form.fieldErrors.email[0]}</p>
				{/if}
			</div>
			<div class="space-y-2">
				<Label for="password">{de.auth.password}</Label>
				<Input
					id="password"
					name="password"
					type="password"
					autocomplete="current-password"
					required
					bind:value={password}
				/>
				{#if form?.fieldErrors?.password}
					<p class="text-xs text-destructive">{form.fieldErrors.password[0]}</p>
				{/if}
			</div>
			<Button type="submit" class="w-full">{de.auth.submitLogin}</Button>
		</form>
		<p class="mt-4 text-center text-sm text-muted-foreground">
			{de.auth.noAccount}
			<a class="text-primary underline-offset-4 hover:underline" href={resolve('/register')}>
				{de.auth.register}</a
			>
		</p>
	</CardContent>
</Card>
