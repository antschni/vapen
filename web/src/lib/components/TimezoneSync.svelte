<script lang="ts">
	import { browser } from '$app/env';
	import { resolve } from '$app/paths';
	import { invalidateAll } from '$app/navigation';
	import { readBrowserTimezone } from '#lib/browser-timezone.js';

	let { storedTimezone }: { storedTimezone: string } = $props();

	// Not reactive on purpose: remembers which timezone we already tried so a
	// failed sync is not retried in a loop every time the effect re-runs.
	let attemptedTimezone: string | null = null;

	$effect(() => {
		if (!browser) return;
		const tz = readBrowserTimezone();
		if (!tz || tz === storedTimezone || tz === attemptedTimezone) return;

		attemptedTimezone = tz;
		void fetch(resolve('timezone/sync'), {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ timezone: tz })
		})
			.then((res) => {
				if (res.ok) return invalidateAll();
			})
			.catch(() => {});
	});
</script>
