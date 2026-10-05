<script lang="ts">
	import { useRegisterSW } from 'virtual:pwa-register/svelte';
	import { RefreshCw } from '@lucide/svelte';
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
		class="fixed right-4 bottom-4 left-4 z-50 flex items-start gap-3 rounded-xl border border-border/70 bg-popover p-4 text-popover-foreground shadow-raised sm:left-auto sm:max-w-sm"
		role="status"
		aria-live="polite"
	>
		<span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
			<RefreshCw class="size-4" />
		</span>
		<div class="flex-1">
			<p class="text-sm font-medium">A new version of Vapen is available.</p>
			<div class="mt-3 flex gap-2">
				<Button type="button" size="sm" onclick={() => updateServiceWorker(true)}>Reload</Button>
				<Button type="button" size="sm" variant="ghost" onclick={() => (dismissed = true)}>Later</Button>
			</div>
		</div>
	</div>
{/if}
