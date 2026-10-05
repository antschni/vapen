<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { HTMLAttributes } from 'svelte/elements';
	import type { Snippet } from 'svelte';

	type Props = HTMLAttributes<HTMLDivElement> & {
		class?: string;
		children?: Snippet;
		actions?: Snippet;
	};

	let { class: className, children, actions, ...rest }: Props = $props();
</script>

<div class={cn('flex items-start justify-between gap-3 px-5 pt-5 pb-4', className)} {...rest}>
	<div class="min-w-0 flex-1 space-y-1">
		{@render children?.()}
	</div>
	{#if actions}
		<div class="flex shrink-0 items-center gap-2">
			{@render actions()}
		</div>
	{/if}
</div>
