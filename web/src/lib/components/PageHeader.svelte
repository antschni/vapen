<script lang="ts">
	import LiveStatsBadge from '#lib/components/LiveStatsBadge.svelte';

	let {
		title,
		description = undefined,
		liveStats = false
	}: {
		title: string;
		description?: string;
		liveStats?: boolean;
	} = $props();
</script>

<header class="mb-6 flex flex-wrap items-start justify-between gap-4 md:mb-8">
	<div class="min-w-0 flex-1">
		<h1 class="text-2xl font-bold tracking-tight md:text-3xl">{title}</h1>
		{#if description}
			<p class="mt-1.5 max-w-2xl text-sm text-muted-foreground md:text-base">{description}</p>
		{/if}
	</div>
	{#if liveStats}
		<LiveStatsBadge />
	{/if}
</header>
