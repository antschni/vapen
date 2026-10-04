<script lang="ts">
	import AppShell from '#lib/components/AppShell.svelte';
	import TimezoneSync from '#lib/components/TimezoneSync.svelte';

	let { data, children } = $props();
</script>

<TimezoneSync storedTimezone={data.user.timezone} />

<AppShell user={data.user}>
	{@render children()}
</AppShell>
