<script lang="ts">
	import { browser } from '$app/env';
	import { resolve } from '$app/paths';
	import { invalidateAll } from '$app/navigation';
	import { readBrowserTimezone } from '#lib/browser-timezone.js';

	let { storedTimezone }: { storedTimezone: string } = $props();

	let syncing = $state(false);

	$effect(() => {
		if (!browser || syncing) return;
		const tz = readBrowserTimezone();
		if (!tz || tz === storedTimezone) return;

		syncing = true;
		fetch(resolve('timezone/sync'), {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ timezone: tz })
		})
			.then((res) => {
				if (res.ok) return invalidateAll();
			})
			.finally(() => {
				syncing = false;
			});
	});
</script>
