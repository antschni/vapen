<script lang="ts">
	import { Label } from 'bits-ui';
	import { cn } from '#lib/utils.js';
	import type { Snippet } from 'svelte';

	type Props = Label.RootProps & {
		class?: string;
		children?: Snippet;
	};

	let { class: className, children, ...rest }: Props = $props();
</script>

<Label.Root
	class={cn(
		'text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70',
		className
	)}
	{...rest}
>
	{@render children?.()}
</Label.Root>
