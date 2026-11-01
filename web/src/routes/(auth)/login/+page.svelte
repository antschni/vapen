<script lang="ts">
	import { resolve } from '$app/paths';
	import { enhance } from '$app/forms';
	import { CircleAlert } from '@lucide/svelte';
	import { de } from '#lib/i18n/de.js';
	import Button from '#lib/components/ui/button.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import type { PageData } from './$types';
	import type { AuthFormState } from '#lib/types/form.js';

	let { data, form }: { data: PageData; form?: AuthFormState } = $props();

	let email = $state('');
	let password = $state('');
</script>

<div>
	<h1 class="text-[28px] leading-9 font-semibold tracking-[-0.025em]">{de.auth.login}</h1>
	<p class="mt-1.5 text-[15px] text-muted-foreground">{de.auth.loginSubtitle}</p>
	<div class="mt-8">
		<form method="POST" class="space-y-5" use:enhance>
			{#if data.redirectTo}
				<input type="hidden" name="redirectTo" value={data.redirectTo} />
			{/if}
			{#if form?.message}
				<p
					class="flex items-center gap-2 rounded-xl bg-destructive/8 px-3.5 py-2.5 text-sm text-destructive ring-1 ring-destructive/20"
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
				<Label for="password">{de.auth.password}</Label>
				<Input
					id="password"
					name="password"
					type="password"
					autocomplete="current-password"
					required
					bind:value={password}
					aria-invalid={form?.fieldErrors?.password ? true : undefined}
				/>
				{#if form?.fieldErrors?.password}
					<p class="text-xs text-destructive">{form.fieldErrors.password[0]}</p>
				{/if}
			</div>
			<Button type="submit" size="lg" class="w-full">{de.auth.submitLogin}</Button>
		</form>
	</div>
</div>

<p class="mt-8 text-sm text-muted-foreground">
	{de.auth.noAccount}
	<a class="font-medium text-primary underline-offset-4 hover:underline" href={resolve('register')}>{de.auth.register}</a>
</p>
