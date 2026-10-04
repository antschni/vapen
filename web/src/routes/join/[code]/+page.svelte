<script lang="ts">
	import { enhance } from '$app/forms';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import { de } from '#lib/i18n/de.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();
</script>

<svelte:head>
	<title>{de.pages.join.title} · {de.app.name}</title>
</svelte:head>

<div class="mx-auto max-w-md pt-12">
	<Card>
		<CardHeader>
			<CardTitle>{de.pages.join.title}</CardTitle>
			<p class="text-sm text-muted-foreground">{de.pages.join.subtitle}</p>
		</CardHeader>
		<CardContent>
			{#if form?.message}
				<p class="mb-4 text-sm text-destructive" role="alert">{form.message}</p>
			{/if}
			<p class="mb-4 font-mono text-sm">{data.code}</p>
			<form method="POST" use:enhance>
				<Button type="submit" class="w-full">{de.pages.join.confirm}</Button>
			</form>
		</CardContent>
	</Card>
</div>
