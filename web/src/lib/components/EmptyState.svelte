<script lang="ts">
	let { title, description }: { title: string; description: string } = $props();
</script>

<div
	class="flex flex-col items-center justify-center rounded-xl border border-dashed border-border/80 bg-muted/25 px-6 py-14 text-center"
>
	<p class="text-lg font-medium">{title}</p>
	<p class="mt-2 max-w-md text-sm text-muted-foreground">{description}</p>
</div>
