<script lang="ts">
	import { Switch } from 'bits-ui';
	import { cn } from '$lib/utils';

	type Props = Switch.RootProps & {
		class?: string;
	};

	let {
		class: className,
		checked = $bindable(false),
		...rest
	}: Props = $props();
</script>

<Switch.Root
	bind:checked
	class={cn(
		'peer inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 data-[state=checked]:bg-primary data-[state=unchecked]:bg-input',
		className
	)}
	{...rest}
>
	<Switch.Thumb
		class="pointer-events-none block h-4 w-4 rounded-full bg-background shadow-lg ring-0 transition-transform data-[state=checked]:translate-x-4 data-[state=unchecked]:translate-x-0"
	/>
</Switch.Root>
