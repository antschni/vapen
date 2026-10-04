<script lang="ts">
	import { browser } from '$app/environment';
	import { invalidateAll } from '$app/navigation';
	import { readBrowserTimezone } from '#lib/browser-timezone.js';

	let { storedTimezone }: { storedTimezone: string } = $props();

	let syncing = $state(false);

	$effect(() => {
		if (!browser || syncing) return;
		const tz = readBrowserTimezone();
		if (!tz || tz === storedTimezone) return;

		syncing = true;
		const body = new FormData();
		body.set('timezone', tz);
		fetch('?/syncTimezone', { method: 'POST', body })
			.then((res) => {
				if (res.ok) return invalidateAll();
			})
			.finally(() => {
				syncing = false;
			});
	});
</script>
