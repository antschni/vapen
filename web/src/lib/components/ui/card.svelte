<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { HTMLAttributes } from 'svelte/elements';
	import type { Snippet } from 'svelte';

	type Props = HTMLAttributes<HTMLDivElement> & {
		class?: string;
		children?: Snippet;
	};

	let { class: className, children, ...rest }: Props = $props();
</script>

<div
	class={cn(
		'rounded-xl border bg-card text-card-foreground shadow-sm ring-1 ring-black/5 dark:ring-white/5',
		className
	)}
	{...rest}
>
	{@render children?.()}
</div>
