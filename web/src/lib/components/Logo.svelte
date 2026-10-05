<script lang="ts">
	import { cn } from '#lib/utils.js';
	import { de } from '#lib/i18n/de.js';

	let {
		showText = true,
		size = 'md',
		class: className
	}: {
		showText?: boolean;
		size?: 'sm' | 'md' | 'lg';
		class?: string;
	} = $props();

	const iconSize = $derived(
		size === 'sm' ? 'h-7 w-7' : size === 'lg' ? 'h-11 w-11' : 'h-8 w-8'
	);
	const textSize = $derived(
		size === 'sm' ? 'text-sm' : size === 'lg' ? 'text-xl' : 'text-base'
	);
</script>

<span class={cn('inline-flex items-center gap-2.5', className)}>
	<svg
		class={cn('shrink-0', iconSize)}
		viewBox="0 0 32 32"
		fill="none"
		xmlns="http://www.w3.org/2000/svg"
		aria-hidden="true"
	>
		<rect width="32" height="32" rx="8" class="fill-primary" />
		<ellipse cx="16" cy="11" rx="5.5" ry="3" fill="white" opacity="0.65" />
		<ellipse cx="16" cy="16" rx="4" ry="2.5" fill="white" opacity="0.85" />
		<circle cx="16" cy="21" r="2.25" fill="white" />
	</svg>
	{#if showText}
		<span class={cn('font-semibold tracking-tight text-foreground', textSize)}>{de.app.name}</span>
	{/if}
</span>
