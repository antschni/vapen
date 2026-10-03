<script lang="ts">
	import Label from '$lib/components/ui/label.svelte';
	import type { PrivacyFlag } from '$lib/privacy';
	import { de } from '$lib/i18n/de';

	let {
		flag,
		name,
		value = $bindable<'inherit' | 'on' | 'off'>('inherit')
	}: {
		flag: PrivacyFlag;
		name: string;
		value?: 'inherit' | 'on' | 'off';
	} = $props();

	const meta = $derived(de.pages.privacy.flags[flag]);
</script>

<div class="space-y-2 rounded-lg border border-border p-4">
	<Label class="font-medium">{meta.label}</Label>
	<p class="text-xs text-muted-foreground">{meta.description}</p>
	<select
		{name}
		class="flex h-9 w-full rounded-md border border-input bg-background px-3 py-1 text-sm"
		bind:value={value}
	>
		<option value="inherit">{de.pages.privacy.inherit}</option>
		<option value="on">{de.pages.privacy.on}</option>
		<option value="off">{de.pages.privacy.off}</option>
	</select>
</div>
