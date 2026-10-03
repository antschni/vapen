<script lang="ts">
	import type { components } from '$lib/api/schema.d.ts';
	import { formatDurationMs } from '$lib/format';

	type Cell = components['schemas']['HeatmapPoint'];

	const weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

	let { cells, ariaLabel }: { cells: Cell[]; ariaLabel: string } = $props();

	const grid = $derived.by(() => {
		const map = new Map<string, Cell>();
		for (const c of cells) {
			map.set(`${c.iso_weekday}-${c.hour}`, c);
		}
		let max = 1;
		for (const c of cells) max = Math.max(max, c.puff_count);
		return { map, max };
	});

	function intensity(count: number): number {
		return count <= 0 ? 0 : 0.15 + (count / grid.max) * 0.85;
	}
</script>

<div class="overflow-x-auto" role="img" aria-label={ariaLabel}>
	<div class="inline-grid grid-cols-[auto_repeat(24,minmax(0.75rem,1fr))] gap-px text-[10px]">
		<div></div>
		{#each Array.from({ length: 24 }, (_, h) => h) as hour}
			<div class="text-center text-muted-foreground">{hour}</div>
		{/each}
		{#each [1, 2, 3, 4, 5, 6, 7] as wd}
			<div class="pr-1 text-muted-foreground">{weekdayLabels[wd - 1]}</div>
			{#each Array.from({ length: 24 }, (_, h) => h) as hour}
				{@const cell = grid.map.get(`${wd}-${hour}`)}
				{@const count = cell?.puff_count ?? 0}
				<div
					class="aspect-square rounded-sm border border-border/50"
					style="background-color: color-mix(in oklab, var(--color-primary) {intensity(count) *
						100}%, transparent)"
					title="{weekdayLabels[wd - 1]} {hour}:00 – {count} Züge, {formatDurationMs(
						cell?.total_duration_ms ?? 0
					)}"
				></div>
			{/each}
		{/each}
	</div>
</div>
