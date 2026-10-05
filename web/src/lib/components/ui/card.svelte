<script lang="ts">
	import { cn } from '#lib/utils.js';
	import { getLiveRefresh } from '#lib/live/refresh.svelte.js';
	import type { HTMLAttributes } from 'svelte/elements';
	import type { Snippet } from 'svelte';

	type Props = HTMLAttributes<HTMLDivElement> & {
		class?: string;
		animateLive?: boolean;
		children?: Snippet;
	};

	let { class: className, animateLive = false, children, ...rest }: Props = $props();

	const live = $derived(getLiveRefresh());
	let flash = $state(false);

	$effect(() => {
		if (!animateLive) return;
		void live.tick;
		flash = true;
		const timer = setTimeout(() => {
			flash = false;
		}, 550);
		return () => clearTimeout(timer);
	});
</script>

<div
	class={cn(
		'live-kpi-flash rounded-xl border border-border/70 bg-card text-card-foreground shadow-card',
		flash && 'ring-2 ring-primary/20',
		className
	)}
	{...rest}
>
	{@render children?.()}
</div>
