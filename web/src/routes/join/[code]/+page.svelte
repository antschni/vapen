<script lang="ts">
	import { enhance } from '$app/forms';
	import { CircleAlert, Users } from '@lucide/svelte';
	import Logo from '#lib/components/Logo.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import { de } from '#lib/i18n/de.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();
</script>

<svelte:head>
	<title>{de.pages.join.title} · {de.app.name}</title>
</svelte:head>

<div class="auth-backdrop flex min-h-dvh flex-col items-center justify-center px-4 py-10">
	<Logo size="lg" class="mb-8 justify-center" />
	<Card class="w-full max-w-sm p-6 text-center shadow-raised">
		<span class="mx-auto flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
			<Users class="size-6" />
		</span>
		<h1 class="mt-4 text-lg font-semibold tracking-tight">{de.pages.join.title}</h1>
		<p class="mt-1 text-sm text-muted-foreground">{de.pages.join.subtitle}</p>
		<p class="mt-4 inline-block rounded-lg bg-muted px-3 py-1.5 font-mono text-sm tracking-wider">{data.code}</p>
		{#if form?.message}
			<p
				class="mt-4 flex items-center justify-center gap-2 rounded-lg bg-destructive/[0.08] px-3 py-2 text-sm text-destructive"
				role="alert"
			>
				<CircleAlert class="size-4 shrink-0" />
				{form.message}
			</p>
		{/if}
		<form method="POST" class="mt-6" use:enhance>
			<Button type="submit" class="w-full">{de.pages.join.confirm}</Button>
		</form>
	</Card>
</div>
