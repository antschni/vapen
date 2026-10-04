<script lang="ts">
	import Badge from '#lib/components/ui/badge.svelte';
	import { formatRelativeTime } from '#lib/format.js';
	import { derivePresenceStatus, type PresenceStatus } from '#lib/live/status.js';
	import { de } from '#lib/i18n/de.js';

	let {
		displayName,
		vapingSince = null,
		lastPuffAt = null
	}: {
		displayName: string;
		vapingSince: string | null;
		lastPuffAt: string | null;
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

	const initials = $derived(
		displayName
			.split(/\s+/)
			.map((p) => p[0])
			.join('')
			.slice(0, 2)
			.toUpperCase()
	);

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

<div class="flex items-center gap-3 rounded-lg border border-border bg-card p-3">
	<div class="relative flex size-10 shrink-0 items-center justify-center rounded-full bg-muted text-sm font-medium">
		{initials}
		{#if status === 'vaping'}
			<span
				class="absolute -right-0.5 -top-0.5 size-3 animate-pulse rounded-full bg-emerald-500 ring-2 ring-card"
			></span>
		{/if}
	</div>
	<div class="min-w-0 flex-1">
		<p class="truncate font-medium">{displayName}</p>
		<p class="text-xs text-muted-foreground">{statusLabel}</p>
	</div>
	<Badge variant={status === 'vaping' ? 'default' : 'secondary'}>
		{status === 'vaping' ? de.live.vapingShort : status === 'active' ? de.live.activeShort : de.live.idleShort}
	</Badge>
</div>
