<script lang="ts">
	import { formatDurationMs } from '#lib/format.js';

	export type BarPoint = {
		label: string;
		durationMs: number;
		puffCount: number;
	};

	let {
		points,
		ariaLabel,
		animateLive = false,
		formatValue = (point: BarPoint) => `${formatDurationMs(point.durationMs)} · ${point.puffCount} Züge`,
		height = 'h-52',
		tone = 'default'
	}: {
		points: BarPoint[];
		ariaLabel: string;
		animateLive?: boolean;
		formatValue?: (point: BarPoint) => string;
		height?: string;
		/** `inverted` renders light bars for the dark brand panel. */
		tone?: 'default' | 'inverted';
	} = $props();

	const maxDuration = $derived(points.reduce((m, p) => Math.max(m, p.durationMs), 0) || 1);
	const labelEvery = $derived(Math.max(1, Math.ceil(points.length / 12)));
	const inverted = $derived(tone === 'inverted');
</script>

<div class="w-full" role="img" aria-label={ariaLabel}>
	<div class="relative {height}">
		<div class="pointer-events-none absolute inset-x-0 top-0 bottom-6 flex flex-col justify-between" aria-hidden="true">
			{#each [0, 1, 2] as line (line)}
				<div class={['border-t border-dashed', inverted ? 'border-white/10' : 'border-border']}></div>
			{/each}
			<div class={['border-t', inverted ? 'border-white/20' : 'border-border']}></div>
		</div>
		<div class="relative flex h-full gap-1 sm:gap-1.5">
			{#each points as point, i (i)}
				{@const pct = (point.durationMs / maxDuration) * 100}
				<div class="group flex min-w-0 flex-1 flex-col">
					<div class="relative flex-1">
						<div
							class="pointer-events-none absolute left-1/2 z-10 mb-2 hidden -translate-x-1/2 rounded-lg bg-foreground px-2.5 py-1.5 text-[11px] whitespace-nowrap text-background shadow-raised group-hover:block"
							style:bottom="{pct}%"
						>
							<span class="font-semibold">{point.label}</span> · {formatValue(point)}
						</div>
						<div
							class={[
								'absolute inset-x-0 bottom-0 mx-auto max-w-9 rounded-t-md rounded-b-[2px] bg-linear-to-t',
								inverted
									? 'from-white/35 to-white/70 group-hover:from-white/60 group-hover:to-white'
									: 'from-primary/55 to-primary group-hover:from-primary/80',
								animateLive ? 'transition-[height,opacity] duration-700 ease-out' : 'transition-opacity'
							]}
							style:height="{point.durationMs > 0 ? Math.max(2, pct) : 0}%"
						></div>
					</div>
					<span
						class={[
							'mt-2 h-4 truncate text-center text-[11px] tabular-nums',
							inverted ? 'text-white/60' : 'text-muted-foreground',
							i % labelEvery !== 0 && 'invisible'
						]}
					>
						{point.label}
					</span>
				</div>
			{/each}
		</div>
	</div>
	<table class="sr-only">
		<caption>{ariaLabel}</caption>
		<thead>
			<tr>
				<th>Zeitraum</th>
				<th>Wert</th>
			</tr>
		</thead>
		<tbody>
			{#each points as point, i (i)}
				<tr>
					<td>{point.label}</td>
					<td>{formatValue(point)}</td>
				</tr>
			{/each}
		</tbody>
	</table>
</div>
