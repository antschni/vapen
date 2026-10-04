<script lang="ts">
	import { onMount } from 'svelte';
	import { LivePresence } from '#lib/live/presence.svelte.js';
	import LiveMemberCard from '#lib/components/LiveMemberCard.svelte';
	import { de } from '#lib/i18n/de.js';

	let { groupId }: { groupId: string } = $props();

	let presence = $state<LivePresence | null>(null);

	onMount(() => {
		const p = new LivePresence(groupId);
		presence = p;
		p.connect();
		return () => p.destroy();
	});

	const members = $derived(presence?.members ?? []);
</script>

<div class="space-y-2">
	<h3 class="text-sm font-medium text-muted-foreground">{de.live.widgetTitle}</h3>
	{#if members.length === 0}
		<p class="text-sm text-muted-foreground">{de.live.noMembers}</p>
	{:else}
		<div class="space-y-2">
			{#each members.slice(0, 4) as member (member.user_id)}
				<LiveMemberCard
					displayName={member.display_name}
					vapingSince={member.vaping_since}
					lastPuffAt={member.last_puff_at}
				/>
			{/each}
		</div>
	{/if}
</div>
