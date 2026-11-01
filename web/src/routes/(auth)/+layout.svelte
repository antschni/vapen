<script lang="ts">
	import { Check } from '@lucide/svelte';
	import { de } from '#lib/i18n/de.js';
	import Logo from '#lib/components/Logo.svelte';

	let { children } = $props();
</script>

<div class="flex min-h-dvh bg-background lg:p-3">
	<aside
		class="brand-panel relative hidden w-[44%] max-w-xl flex-col justify-between overflow-hidden rounded-3xl p-10 lg:flex"
	>
		<Logo size="md" tone="inverted" />

		<div class="relative">
			<p class="max-w-sm text-4xl leading-tight font-semibold tracking-[-0.03em]">{de.auth.panelHeadline}</p>
			<ul class="mt-8 space-y-3 text-[15px] text-white/80">
				{#each de.auth.panelFeatures as feature (feature)}
					<li class="flex items-center gap-3">
						<span class="flex size-6 items-center justify-center rounded-full bg-white/12">
							<Check class="size-3.5" />
						</span>
						{feature}
					</li>
				{/each}
			</ul>
		</div>

		<p class="text-sm text-white/50">{de.app.tagline}</p>

		<!-- Soft vapor rings -->
		<svg
			class="pointer-events-none absolute -top-24 -right-24 size-96 text-white/10"
			viewBox="0 0 200 200"
			fill="none"
			aria-hidden="true"
		>
			<circle cx="100" cy="100" r="40" stroke="currentColor" />
			<circle cx="100" cy="100" r="62" stroke="currentColor" />
			<circle cx="100" cy="100" r="84" stroke="currentColor" />
			<circle cx="100" cy="100" r="99" stroke="currentColor" />
		</svg>
	</aside>

	<div class="auth-backdrop flex flex-1 flex-col px-5 py-8 sm:px-8 lg:bg-none">
		<div class="lg:hidden">
			<Logo size="sm" />
		</div>
		<div class="flex flex-1 items-center justify-center py-10">
			<div class="w-full max-w-sm">
				{@render children()}
			</div>
		</div>
	</div>
</div>
