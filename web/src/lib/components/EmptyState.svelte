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
		'flex flex-col items-center justify-center rounded-2xl bg-card px-6 py-16 text-center shadow-card',
		className
	)}
>
	{#if Icon}
		<div class="relative mb-5">
			<div class="absolute inset-0 scale-150 rounded-full bg-primary/10 blur-xl" aria-hidden="true"></div>
			<div class="relative flex size-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
				<Icon class="size-6" />
			</div>
		</div>
	{/if}
	<p class="text-base font-semibold tracking-tight">{title}</p>
	{#if description}
		<p class="mt-1 max-w-sm text-sm text-muted-foreground">{description}</p>
	{/if}
</div>
