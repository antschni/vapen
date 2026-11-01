<script lang="ts">
	import { cn } from '#lib/utils.js';
	import { de } from '#lib/i18n/de.js';

	let {
		showText = true,
		size = 'md',
		tone = 'default',
		class: className
	}: {
		showText?: boolean;
		size?: 'sm' | 'md' | 'lg';
		/** `inverted` for placement on the dark brand panel. */
		tone?: 'default' | 'inverted';
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
		<rect width="32" height="32" rx="9" class={tone === 'inverted' ? 'fill-white' : 'fill-primary'} />
		<g class={tone === 'inverted' ? 'fill-brand-ink' : 'fill-white'}>
			<ellipse cx="16" cy="11" rx="5.5" ry="3" opacity="0.65" />
			<ellipse cx="16" cy="16" rx="4" ry="2.5" opacity="0.85" />
			<circle cx="16" cy="21" r="2.25" />
		</g>
	</svg>
	{#if showText}
		<span class={cn('font-semibold tracking-tight', tone === 'inverted' ? 'text-white' : 'text-foreground', textSize)}>{de.app.name}</span>
	{/if}
</span>
