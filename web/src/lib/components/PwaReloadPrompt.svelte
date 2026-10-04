<script lang="ts">
	import { useRegisterSW } from 'virtual:pwa-register/svelte';
	import Button from '#lib/components/ui/button.svelte';

	const { needRefresh, updateServiceWorker } = useRegisterSW({
		onRegistered(r) {
			if (r) {
				setInterval(() => r.update(), 60 * 60 * 1000);
			}
		}
	});

	let dismissed = $state(false);
</script>

{#if $needRefresh && !dismissed}
	<div
		class="border-border bg-card text-card-foreground fixed bottom-4 left-4 right-4 z-50 flex flex-col gap-3 rounded-lg border p-4 shadow-lg sm:left-auto sm:right-4 sm:max-w-sm"
		role="status"
		aria-live="polite"
	>
		<p class="text-sm">A new version of Vapen is available.</p>
		<div class="flex gap-2">
			<Button type="button" size="sm" onclick={() => updateServiceWorker(true)}>Reload</Button>
			<Button type="button" size="sm" variant="secondary" onclick={() => (dismissed = true)}>
				Later
			</Button>
		</div>
	</div>
{/if}
