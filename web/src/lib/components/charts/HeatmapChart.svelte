<script lang="ts">
	import type { components } from '#lib/api/schema.d.ts';
	import { formatDurationMs } from '#lib/format.js';

	type Cell = components['schemas']['HeatmapPoint'];

	const weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
	const hours = Array.from({ length: 24 }, (_, h) => h);

	let { cells, ariaLabel }: { cells: Cell[]; ariaLabel: string } = $props();

	const grid = $derived.by(() => {
		const map: Record<string, Cell> = {};
		let max = 1;
		for (const c of cells) {
			map[`${c.iso_weekday}-${c.hour}`] = c;
			max = Math.max(max, c.puff_count);
		}
		return { map, max };
	});

	function intensity(count: number): number {
		return count <= 0 ? 0 : 0.18 + (count / grid.max) * 0.82;
	}
</script>

<div class="overflow-x-auto" role="img" aria-label={ariaLabel}>
	<div class="grid min-w-[30rem] grid-cols-[1.75rem_repeat(24,minmax(0,1fr))] gap-[3px] text-[10px]">
		<div></div>
		{#each hours as hour (hour)}
			<div class="text-center text-muted-foreground tabular-nums">{hour % 3 === 0 ? hour : ''}</div>
		{/each}
		{#each [1, 2, 3, 4, 5, 6, 7] as wd (wd)}
			<div class="flex items-center text-muted-foreground">{weekdayLabels[wd - 1]}</div>
			{#each hours as hour (hour)}
				{@const cell = grid.map[`${wd}-${hour}`]}
				{@const count = cell?.puff_count ?? 0}
				<div
					class="aspect-square rounded-[3px] bg-muted transition-transform hover:scale-110"
					style:background-color={count > 0
						? `color-mix(in oklab, var(--color-primary) ${intensity(count) * 100}%, var(--color-muted))`
						: undefined}
					title="{weekdayLabels[wd - 1]} {hour}:00 – {count} Züge, {formatDurationMs(cell?.total_duration_ms ?? 0)}"
				></div>
			{/each}
		{/each}
	</div>
	<div class="mt-3 flex items-center justify-end gap-1.5 text-[10px] text-muted-foreground" aria-hidden="true">
		<span>weniger</span>
		{#each [0, 0.25, 0.5, 0.75, 1] as step (step)}
			<span
				class="size-2.5 rounded-[2px] bg-muted"
				style:background-color={step > 0
					? `color-mix(in oklab, var(--color-primary) ${(0.18 + step * 0.82) * 100}%, var(--color-muted))`
					: undefined}
			></span>
		{/each}
		<span>mehr</span>
	</div>
</div>
