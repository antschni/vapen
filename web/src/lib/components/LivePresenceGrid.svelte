<script lang="ts">
	import { LivePresence } from '#lib/live/presence.svelte.js';
	import LiveMemberCard from '#lib/components/LiveMemberCard.svelte';
	import { de } from '#lib/i18n/de.js';

	let { groupId }: { groupId: string } = $props();

	let presence = $state<LivePresence | null>(null);

	// Re-runs when groupId changes (same route, different group) and tears
	// down the previous stream first.
	$effect(() => {
		const p = new LivePresence(groupId);
		presence = p;
		p.connect();
		return () => p.destroy();
	});

	const members = $derived(presence?.members ?? []);
</script>

{#if !presence?.connected && presence?.error}
	<p class="mb-3 text-xs text-muted-foreground">{de.live.reconnecting}</p>
{/if}
{#if members.length === 0}
	<p class="py-6 text-center text-sm text-muted-foreground">{de.live.noMembers}</p>
{:else}
	<div class="grid gap-2.5 sm:grid-cols-2 lg:grid-cols-3">
		{#each members as member (member.user_id)}
			<LiveMemberCard
				displayName={member.display_name}
				vapingSince={member.vaping_since}
				lastPuffAt={member.last_puff_at}
			/>
		{/each}
	</div>
{/if}
