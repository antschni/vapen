<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { HTMLButtonAttributes } from 'svelte/elements';
	import type { Snippet } from 'svelte';
	import { buttonVariants, type ButtonVariants } from './button-variants.js';

	type Props = HTMLButtonAttributes & {
		variant?: ButtonVariants['variant'];
		size?: ButtonVariants['size'];
		class?: string;
		children?: Snippet;
	};

	let {
		class: className,
		variant = 'default',
		size = 'default',
		type = 'button',
		children,
		...rest
	}: Props = $props();
</script>

<button {type} class={cn(buttonVariants({ variant, size }), className)} {...rest}>
	{@render children?.()}
</button>
