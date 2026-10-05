<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { Snippet } from 'svelte';

	let {
		name,
		size = 'md',
		class: className,
		children
	}: {
		name: string;
		size?: 'sm' | 'md' | 'lg';
		class?: string;
		children?: Snippet;
	} = $props();

	const initials = $derived(
		name
			.trim()
			.split(/\s+/)
			.map((part) => part[0] ?? '')
			.join('')
			.slice(0, 2)
			.toUpperCase()
	);

	const hue = $derived([...name].reduce((sum, char) => sum + char.charCodeAt(0), 0) % 360);
</script>

<span
	class={cn(
		'relative inline-flex shrink-0 items-center justify-center rounded-full font-semibold select-none',
		'bg-[oklch(0.93_0.035_var(--avatar-hue))] text-[oklch(0.38_0.08_var(--avatar-hue))]',
		'dark:bg-[oklch(0.3_0.05_var(--avatar-hue))] dark:text-[oklch(0.88_0.05_var(--avatar-hue))]',
		size === 'sm' && 'size-7 text-[11px]',
		size === 'md' && 'size-9 text-xs',
		size === 'lg' && 'size-11 text-sm',
		className
	)}
	style:--avatar-hue={hue}
	aria-hidden="true"
>
	{initials}
	{@render children?.()}
</span>
