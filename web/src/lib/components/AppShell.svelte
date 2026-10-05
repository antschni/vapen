<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import type { Snippet } from 'svelte';
	import type { SessionUser } from '#lib/session-user.js';
	import { de } from '#lib/i18n/de.js';
	import Logo from '#lib/components/Logo.svelte';
	import Avatar from '#lib/components/ui/avatar.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import { ModeWatcher, toggleMode } from 'mode-watcher';
	import {
		LayoutDashboard,
		ChartColumn,
		Smartphone,
		Users,
		Shield,
		UserRound,
		LogOut,
		Menu,
		Moon,
		Sun,
		X
	} from '@lucide/svelte';
	import { cn } from '#lib/utils.js';

	let { children, user }: { children: Snippet; user: SessionUser } = $props();

	let mobileOpen = $state(false);

	type AppPath = 'usage' | 'devices' | 'groups' | 'settings/privacy' | 'settings/account';
	type NavItem = {
		path: AppPath | null;
		label: string;
		icon: typeof LayoutDashboard;
	};

	const sections: { label: string; items: NavItem[] }[] = [
		{
			label: de.nav.general,
			items: [
				{ path: null, label: de.nav.overview, icon: LayoutDashboard },
				{ path: 'usage', label: de.nav.usage, icon: ChartColumn },
				{ path: 'devices', label: de.nav.devices, icon: Smartphone },
				{ path: 'groups', label: de.nav.groups, icon: Users }
			]
		},
		{
			label: de.nav.settings,
			items: [
				{ path: 'settings/privacy', label: de.nav.privacy, icon: Shield },
				{ path: 'settings/account', label: de.nav.account, icon: UserRound }
			]
		}
	];

	function navHref(item: NavItem): string {
		return item.path === null ? resolve('/(app)') : resolve(item.path);
	}

	function isActive(item: NavItem, pathname: string): boolean {
		if (item.path === null) return pathname === '/';
		const href = `/${item.path}`;
		return pathname === href || pathname.startsWith(`${href}/`);
	}

	function close() {
		mobileOpen = false;
	}
</script>

<svelte:window
	onkeydown={(event) => {
		if (event.key === 'Escape') close();
	}}
/>

<ModeWatcher disableHeadScriptInjection />

<div class="min-h-dvh bg-surface lg:flex">
	<header
		class="sticky top-0 z-30 flex h-14 items-center gap-2 border-b border-border/70 bg-card/80 px-3 backdrop-blur-md lg:hidden"
	>
		<Button variant="ghost" size="icon" aria-label={de.nav.menu} onclick={() => (mobileOpen = true)}>
			<Menu />
		</Button>
		<a href={resolve('/(app)')} class="rounded-md outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30">
			<Logo size="sm" />
		</a>
		<Button variant="ghost" size="icon" class="ml-auto" aria-label={de.nav.toggleTheme} onclick={toggleMode}>
			<Sun class="dark:hidden" />
			<Moon class="hidden dark:block" />
		</Button>
	</header>

	{#if mobileOpen}
		<button
			type="button"
			class="fixed inset-0 z-40 bg-black/30 backdrop-blur-[2px] lg:hidden"
			aria-label={de.common.close}
			onclick={close}
		></button>
	{/if}

	<aside
		class={cn(
			'fixed inset-y-0 left-0 z-50 flex w-64 flex-col border-r border-border/70 bg-card transition-transform duration-200 ease-out',
			'lg:sticky lg:top-0 lg:h-dvh lg:translate-x-0',
			mobileOpen ? 'translate-x-0 shadow-raised' : '-translate-x-full'
		)}
	>
		<div class="flex h-14 items-center justify-between px-4 lg:h-16 lg:px-5">
			<a
				href={resolve('/(app)')}
				class="rounded-md outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30"
				onclick={close}
			>
				<Logo size="sm" />
			</a>
			<Button variant="ghost" size="icon-sm" class="lg:hidden" aria-label={de.common.close} onclick={close}>
				<X />
			</Button>
		</div>

		<nav class="flex flex-1 flex-col gap-6 overflow-y-auto px-3 py-3" aria-label={de.nav.menu}>
			{#each sections as section (section.label)}
				<div>
					<p class="mb-1.5 px-2.5 text-[11px] font-medium tracking-wider text-muted-foreground/80 uppercase">
						{section.label}
					</p>
					<ul class="space-y-0.5">
						{#each section.items as item (item.label)}
							{@const active = isActive(item, page.url.pathname)}
							<li>
								<a
									href={navHref(item)}
									aria-current={active ? 'page' : undefined}
									class={cn(
										'flex h-9 items-center gap-3 rounded-lg px-2.5 text-sm font-medium transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30',
										active
											? 'bg-primary/[0.08] text-primary'
											: 'text-muted-foreground hover:bg-accent/60 hover:text-foreground'
									)}
									onclick={close}
								>
									<item.icon class="size-4 shrink-0" />
									{item.label}
								</a>
							</li>
						{/each}
					</ul>
				</div>
			{/each}
		</nav>

		<div class="border-t border-border/70 p-3">
			<div class="flex items-center gap-2.5 rounded-lg px-1.5 py-1.5">
				<Avatar name={user.display_name} size="sm" />
				<div class="min-w-0 flex-1">
					<p class="truncate text-sm font-medium leading-5">{user.display_name}</p>
					<p class="truncate text-xs text-muted-foreground" title={user.email}>{user.email}</p>
				</div>
				<Button
					variant="ghost"
					size="icon-sm"
					class="hidden lg:inline-flex"
					aria-label={de.nav.toggleTheme}
					title={de.nav.toggleTheme}
					onclick={toggleMode}
				>
					<Sun class="dark:hidden" />
					<Moon class="hidden dark:block" />
				</Button>
				<form method="POST" action="/logout">
					<Button variant="ghost" size="icon-sm" type="submit" aria-label={de.nav.logout} title={de.nav.logout}>
						<LogOut />
					</Button>
				</form>
			</div>
		</div>
	</aside>

	<main class="min-w-0 flex-1 px-4 py-6 md:px-8 md:py-8 lg:px-10 lg:py-10">
		<div class="mx-auto w-full max-w-6xl">{@render children()}</div>
	</main>
</div>
