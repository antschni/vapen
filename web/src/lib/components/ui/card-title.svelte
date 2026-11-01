<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { HTMLAttributes } from 'svelte/elements';
	import type { Snippet } from 'svelte';

	type Props = HTMLAttributes<HTMLHeadingElement> & {
		class?: string;
		children?: Snippet;
	};

	let { class: className, children, ...rest }: Props = $props();
</script>

<h3 class={cn('text-[15px] leading-6 font-semibold tracking-[-0.01em]', className)} {...rest}>
	{@render children?.()}
</h3>
