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
	class={cn('rounded-xl border border-border/70 bg-card text-card-foreground shadow-card', className)}
	{...rest}
>
	{@render children?.()}
</div>
