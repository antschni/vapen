<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { HTMLInputAttributes } from 'svelte/elements';

	type Props = Omit<HTMLInputAttributes, 'type'> & {
		class?: string;
	};

	let { class: className, checked = $bindable(false), ...rest }: Props = $props();
</script>

<input
	type="checkbox"
	role="switch"
	class={cn(
		"relative h-5 w-9 shrink-0 cursor-pointer appearance-none rounded-full bg-input transition-colors outline-none before:absolute before:top-0.5 before:left-0.5 before:size-4 before:rounded-full before:bg-background before:shadow-sm before:transition-transform before:content-[''] checked:bg-primary checked:before:translate-x-4 focus-visible:ring-[3px] focus-visible:ring-ring/30 disabled:cursor-not-allowed disabled:opacity-50",
		className
	)}
	bind:checked
	{...rest}
/>
