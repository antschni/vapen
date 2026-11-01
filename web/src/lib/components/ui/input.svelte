<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { HTMLInputAttributes } from 'svelte/elements';

	type Props = HTMLInputAttributes & {
		class?: string;
	};

	let { class: className, value = $bindable(), ...rest }: Props = $props();
</script>

<input
	class={cn(
		'flex h-10 w-full min-w-0 rounded-lg border border-input bg-card px-3.5 text-sm transition-[border-color,box-shadow] outline-none file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground/70 focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/20 disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground aria-invalid:border-destructive aria-invalid:ring-destructive/15',
		className
	)}
	bind:value
	{...rest}
/>
