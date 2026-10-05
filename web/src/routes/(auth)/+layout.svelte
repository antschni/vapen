<script lang="ts">
	import { de } from '#lib/i18n/de.js';
	import Logo from '#lib/components/Logo.svelte';

	let { children } = $props();
</script>

<div class="auth-backdrop flex min-h-dvh flex-col items-center justify-center p-4">
	<div class="mb-8 flex flex-col items-center text-center">
		<Logo size="lg" class="justify-center" />
		<p class="mt-3 text-sm text-muted-foreground">{de.app.tagline}</p>
	</div>
	<div class="w-full max-w-md">
		{@render children()}
	</div>
</div>
