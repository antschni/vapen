<script lang="ts">
	import { fly } from 'svelte/transition';
	import { de } from '#lib/i18n/de.js';
	import { dismissToast, getToasts } from '#lib/notifications.svelte.js';

	const toasts = $derived(getToasts());
</script>

<div class="pointer-events-none fixed inset-x-0 bottom-4 z-50 flex flex-col items-center gap-2 px-4 sm:items-end sm:px-6">
	{#each toasts as toast (toast.id)}
		<div
			class="pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-lg border px-4 py-3 text-sm shadow-lg {toast.kind ===
			'error'
				? 'border-destructive/30 bg-destructive text-destructive-foreground'
				: 'border-border bg-card text-card-foreground'}"
			role="status"
			aria-live="polite"
			transition:fly={{ y: 12, duration: 180 }}
		>
			<span class="flex-1">{toast.message}</span>
			<button
				type="button"
				class="rounded-md px-1 text-current/70 hover:text-current"
				aria-label={de.common.close}
				onclick={() => dismissToast(toast.id)}
			>
				×
			</button>
		</div>
	{/each}
</div>
