<script lang="ts">
	import { ChevronDown } from '@lucide/svelte';
	import { cn } from '#lib/utils.js';
	import type { HTMLSelectAttributes } from 'svelte/elements';
	import type { Snippet } from 'svelte';

	type Props = HTMLSelectAttributes & {
		class?: string;
		children?: Snippet;
	};

	let { class: className, value = $bindable(), children, ...rest }: Props = $props();
</script>

<div class={cn('relative', className)}>
	<select
		class="flex h-9 w-full appearance-none rounded-lg border border-input bg-background pr-9 pl-3 text-sm shadow-card transition-[border-color,box-shadow] outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/20 disabled:cursor-not-allowed disabled:opacity-50"
		bind:value
		{...rest}
	>
		{@render children?.()}
	</select>
	<ChevronDown
		class="pointer-events-none absolute top-1/2 right-3 size-4 -translate-y-1/2 text-muted-foreground"
		aria-hidden="true"
	/>
</div>
