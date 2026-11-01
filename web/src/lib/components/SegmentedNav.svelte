<script lang="ts">
	import type { Component } from 'svelte';
	import { cn } from '#lib/utils.js';

	type Item = {
		href: string;
		label: string;
		active: boolean;
		icon?: Component<{ class?: string }>;
	};

	let {
		items,
		label,
		size = 'md',
		class: className
	}: {
		items: Item[];
		label: string;
		size?: 'sm' | 'md';
		class?: string;
	} = $props();
</script>

<nav class={cn('inline-flex rounded-full bg-muted p-1', className)} aria-label={label}>
	{#each items as item (item.href)}
		<a
			href={item.href}
			aria-current={item.active ? 'page' : undefined}
			class={cn(
				'inline-flex items-center gap-1.5 rounded-full font-medium whitespace-nowrap transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30',
				size === 'md' ? 'h-8 px-3.5 text-sm' : 'h-7 px-3 text-xs',
				item.active
					? 'bg-card text-foreground shadow-card'
					: 'text-muted-foreground hover:text-foreground'
			)}
		>
			{#if item.icon}
				<item.icon class="size-4" />
			{/if}
			{item.label}
		</a>
	{/each}
</nav>
