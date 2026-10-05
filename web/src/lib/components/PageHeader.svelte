<script lang="ts">
	let {
		title,
		description = undefined
	}: {
		title: string;
		description?: string;
	} = $props();
</script>

<header class="mb-6 md:mb-8">
	<h1 class="text-2xl font-bold tracking-tight md:text-3xl">{title}</h1>
	{#if description}
		<p class="mt-1.5 max-w-2xl text-sm text-muted-foreground md:text-base">{description}</p>
	{/if}
</header>
