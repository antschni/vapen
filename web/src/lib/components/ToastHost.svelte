<script lang="ts">
	import { fly } from 'svelte/transition';
	import { CircleAlert, CircleCheck, X } from '@lucide/svelte';
	import { de } from '#lib/i18n/de.js';
	import { dismissToast, getToasts } from '#lib/notifications.svelte.js';

	const toasts = $derived(getToasts());
</script>

<div class="pointer-events-none fixed inset-x-0 bottom-4 z-50 flex flex-col items-center gap-2 px-4 sm:items-end sm:px-6">
	{#each toasts as toast (toast.id)}
		<div
			class="pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-xl border border-border/70 bg-popover py-3 pr-2 pl-3.5 text-sm text-popover-foreground shadow-raised"
			role="status"
			aria-live="polite"
			transition:fly={{ y: 12, duration: 180 }}
		>
			{#if toast.kind === 'error'}
				<CircleAlert class="mt-0.5 size-4 shrink-0 text-destructive" aria-hidden="true" />
			{:else}
				<CircleCheck class="mt-0.5 size-4 shrink-0 text-emerald-600 dark:text-emerald-400" aria-hidden="true" />
			{/if}
			<span class="flex-1 leading-5">{toast.message}</span>
			<button
				type="button"
				class="-my-0.5 rounded-md p-1 text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
				aria-label={de.common.close}
				onclick={() => dismissToast(toast.id)}
			>
				<X class="size-3.5" />
			</button>
		</div>
	{/each}
</div>
