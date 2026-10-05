<script lang="ts">
	import type { Component } from 'svelte';
	import { cn } from '#lib/utils.js';

	let {
		title,
		description,
		icon: Icon = undefined,
		class: className
	}: {
		title: string;
		description?: string;
		icon?: Component<{ class?: string }>;
		class?: string;
	} = $props();
</script>

<div
	class={cn(
		'flex flex-col items-center justify-center rounded-xl border border-dashed border-border px-6 py-12 text-center',
		className
	)}
>
	{#if Icon}
		<div class="mb-4 flex size-11 items-center justify-center rounded-full bg-primary/10 text-primary">
			<Icon class="size-5" />
		</div>
	{/if}
	<p class="font-medium">{title}</p>
	{#if description}
		<p class="mt-1 max-w-sm text-sm text-muted-foreground">{description}</p>
	{/if}
</div>
