<script lang="ts">
	import { formatDurationMs } from '$lib/format';

	export type BarPoint = {
		label: string;
		durationMs: number;
		puffCount: number;
	};

	let {
		points,
		ariaLabel
	}: {
		points: BarPoint[];
		ariaLabel: string;
	} = $props();

	const maxDuration = $derived(
		points.reduce((m, p) => Math.max(m, p.durationMs), 1)
	);
</script>

<div class="w-full" role="img" aria-label={ariaLabel}>
	<div class="flex h-48 items-end gap-1 sm:gap-2">
		{#each points as point (point.label)}
			<div class="flex min-w-0 flex-1 flex-col items-center gap-1">
				<div
					class="w-full rounded-t bg-primary/80 transition-all"
					style="height: {Math.max(4, (point.durationMs / maxDuration) * 100)}%"
					title="{point.label}: {formatDurationMs(point.durationMs)}, {point.puffCount} Züge"
				></div>
				<span class="truncate text-[10px] text-muted-foreground sm:text-xs">{point.label}</span>
			</div>
		{/each}
	</div>
	<table class="sr-only">
		<caption>{ariaLabel}</caption>
		<thead>
			<tr>
				<th>Zeitraum</th>
				<th>Dauer</th>
				<th>Züge</th>
			</tr>
		</thead>
		<tbody>
			{#each points as point}
				<tr>
					<td>{point.label}</td>
					<td>{formatDurationMs(point.durationMs)}</td>
					<td>{point.puffCount}</td>
				</tr>
			{/each}
		</tbody>
	</table>
</div>
