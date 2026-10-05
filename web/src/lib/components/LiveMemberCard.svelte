<script lang="ts">
	import Avatar from '#lib/components/ui/avatar.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import { formatRelativeTime } from '#lib/format.js';
	import { derivePresenceStatus, type PresenceStatus } from '#lib/live/status.js';
	import { de } from '#lib/i18n/de.js';
	import { cn } from '#lib/utils.js';

	let {
		displayName,
		vapingSince = null,
		lastPuffAt = null,
		variant = 'card'
	}: {
		displayName: string;
		vapingSince: string | null;
		lastPuffAt: string | null;
		variant?: 'card' | 'row';
	} = $props();

	let status = $state<PresenceStatus>('idle');

	$effect(() => {
		const update = () => {
			status = derivePresenceStatus(vapingSince, lastPuffAt);
		};
		update();
		const id = setInterval(update, 2000);
		return () => clearInterval(id);
	});

	const statusLabel = $derived(
		status === 'vaping'
			? de.live.vaping
			: status === 'active'
				? lastPuffAt
					? de.live.activeSince(formatRelativeTime(lastPuffAt))
					: de.live.active
				: de.live.idle
	);
</script>

<div
	class={cn(
		'flex items-center gap-3',
		variant === 'card' && 'rounded-lg border border-border/70 bg-surface p-3',
		variant === 'row' && 'py-2.5',
		status === 'vaping' && variant === 'card' && 'border-emerald-500/30 bg-emerald-500/[0.05]'
	)}
>
	<Avatar name={displayName}>
		<span
			class={cn(
				'absolute -right-0.5 -bottom-0.5 size-3 rounded-full ring-2 ring-card',
				status === 'vaping' && 'bg-emerald-500 motion-safe:animate-pulse',
				status === 'active' && 'bg-amber-400',
				status === 'idle' && 'bg-muted-foreground/40'
			)}
		></span>
	</Avatar>
	<div class="min-w-0 flex-1">
		<p class="truncate text-sm font-medium">{displayName}</p>
		<p class="truncate text-xs text-muted-foreground">{statusLabel}</p>
	</div>
	{#if status === 'vaping'}
		<Badge variant="success">{de.live.vapingShort}</Badge>
	{:else if status === 'active'}
		<Badge variant="warning">{de.live.activeShort}</Badge>
	{/if}
</div>
