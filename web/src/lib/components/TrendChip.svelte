<script lang="ts">
	import { ArrowDownRight, ArrowRight, ArrowUpRight } from '@lucide/svelte';
	import { cn } from '#lib/utils.js';

	let {
		label,
		positive,
		up,
		flat = false,
		tone = 'default'
	}: {
		label: string;
		/** Whether the change is good news (less usage). */
		positive: boolean;
		up: boolean;
		/** No change: neutral styling and a sideways arrow. */
		flat?: boolean;
		/** `inverted` for use on the dark brand panel. */
		tone?: 'default' | 'inverted';
	} = $props();

	const Icon = $derived(flat ? ArrowRight : up ? ArrowUpRight : ArrowDownRight);
</script>

<span
	class={cn(
		'inline-flex h-6 items-center gap-1 rounded-full pr-2.5 pl-1.5 text-xs font-medium tabular-nums',
		flat && (tone === 'default' ? 'bg-muted text-muted-foreground' : 'bg-white/12 text-white/70'),
		!flat &&
			tone === 'default' &&
			(positive
				? 'bg-success/12 text-[color-mix(in_oklch,var(--success)_75%,var(--foreground))]'
				: 'bg-warning/15 text-[color-mix(in_oklch,var(--warning)_60%,var(--foreground))]'),
		!flat && tone === 'inverted' && (positive ? 'bg-white/12 text-emerald-200' : 'bg-white/12 text-amber-200')
	)}
>
	<Icon class="size-3.5" />
	{label}
</span>
