<script lang="ts">
	import type { PrivacyFlag } from '#lib/privacy.js';
	import { de } from '#lib/i18n/de.js';

	type TriValue = 'inherit' | 'on' | 'off';

	let {
		flag,
		name,
		value = $bindable<TriValue>('inherit')
	}: {
		flag: PrivacyFlag;
		name: string;
		value?: TriValue;
	} = $props();

	const meta = $derived(de.pages.privacy.flags[flag]);

	const options: { value: TriValue; label: string }[] = [
		{ value: 'inherit', label: de.pages.privacy.inherit },
		{ value: 'on', label: de.pages.privacy.on },
		{ value: 'off', label: de.pages.privacy.off }
	];
</script>

<div class="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between sm:gap-6">
	<div class="min-w-0">
		<p class="text-sm font-medium">{meta.label}</p>
		<p class="mt-0.5 text-xs text-muted-foreground">{meta.description}</p>
	</div>
	<div
		class="inline-flex shrink-0 self-start rounded-lg bg-muted p-0.5 sm:self-center"
		role="radiogroup"
		aria-label={meta.label}
	>
		{#each options as option (option.value)}
			<label
				class="relative cursor-pointer rounded-md px-3 py-1 text-xs font-medium text-muted-foreground transition-colors hover:text-foreground has-checked:bg-card has-checked:text-foreground has-checked:shadow-card has-focus-visible:ring-[3px] has-focus-visible:ring-ring/30"
			>
				<input type="radio" class="sr-only" {name} value={option.value} bind:group={value} />
				{option.label}
			</label>
		{/each}
	</div>
</div>
