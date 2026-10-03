<script lang="ts">
	import { de } from '$lib/i18n/de';

	let { children } = $props();
</script>

<div class="flex min-h-dvh flex-col items-center justify-center bg-muted/30 p-4">
	<div class="mb-6 text-center">
		<h1 class="text-2xl font-bold tracking-tight">{de.app.name}</h1>
		<p class="text-sm text-muted-foreground">{de.app.tagline}</p>
	</div>
	<div class="w-full max-w-md">
		{@render children()}
	</div>
</div>
