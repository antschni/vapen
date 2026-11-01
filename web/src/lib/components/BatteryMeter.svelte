<script lang="ts">
	import { cn } from '#lib/utils.js';

	let { percent, class: className }: { percent: number; class?: string } = $props();

	const segments = 10;
	const filled = $derived(Math.round((Math.min(100, Math.max(0, percent)) / 100) * segments));
	const tone = $derived(percent <= 15 ? 'bg-destructive' : percent <= 35 ? 'bg-warning' : 'bg-success');
</script>

<div class={cn('flex gap-1', className)} aria-hidden="true">
	{#each Array.from({ length: segments }, (_, i) => i) as i (i)}
		<span class={cn('h-2 flex-1 rounded-full transition-colors', i < filled ? tone : 'bg-muted')}></span>
	{/each}
</div>
