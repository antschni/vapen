<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import type { Snippet } from 'svelte';
	import { DropdownMenu } from 'bits-ui';
	import type { SessionUser } from '#lib/session-user.js';
	import { de } from '#lib/i18n/de.js';
	import Logo from '#lib/components/Logo.svelte';
	import Avatar from '#lib/components/ui/avatar.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import { ModeWatcher, toggleMode } from 'mode-watcher';
	import {
		ChartColumn,
		House,
		LogOut,
		Moon,
		Settings,
		Shield,
		Smartphone,
		Sun,
		UserRound,
		Users
	} from '@lucide/svelte';
	import { cn } from '#lib/utils.js';

	let { children, user }: { children: Snippet; user: SessionUser } = $props();

	type AppPath = 'usage' | 'devices' | 'groups' | 'settings/account';
	type NavItem = {
		path: AppPath | null;
		/** Prefix that marks the item active; defaults to the path itself. */
		match?: string;
		label: string;
		icon: typeof House;
	};

	const items: NavItem[] = [
		{ path: null, label: de.nav.overview, icon: House },
		{ path: 'usage', label: de.nav.usage, icon: ChartColumn },
		{ path: 'devices', label: de.nav.devices, icon: Smartphone },
		{ path: 'groups', label: de.nav.groups, icon: Users },
		{ path: 'settings/account', match: 'settings', label: de.nav.settings, icon: Settings }
	];

	function navHref(item: NavItem): string {
		return item.path === null ? resolve('/(app)') : resolve(item.path);
	}

	function isActive(item: NavItem, pathname: string): boolean {
		if (item.path === null) return pathname === '/';
		const href = `/${item.match ?? item.path}`;
		return pathname === href || pathname.startsWith(`${href}/`);
	}

	let logoutForm = $state<HTMLFormElement | null>(null);

	const menuItemClass =
		'flex h-9 cursor-pointer items-center gap-2.5 rounded-lg px-2.5 text-sm outline-none select-none data-highlighted:bg-accent [&_svg]:size-4 [&_svg]:text-muted-foreground';
</script>

<ModeWatcher disableHeadScriptInjection />

<form method="POST" action="/logout" bind:this={logoutForm} class="hidden"></form>

<div class="min-h-dvh">
	<header class="sticky top-0 z-30 border-b border-border/70 bg-background/80 backdrop-blur-xl">
		<div class="mx-auto flex h-16 w-full max-w-6xl items-center gap-4 px-4 md:px-6">
			<a
				href={resolve('/(app)')}
				class="rounded-lg outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30"
			>
				<Logo size="sm" />
			</a>

			<nav class="ml-4 hidden md:block" aria-label={de.nav.menu}>
				<ul class="flex items-center gap-1">
					{#each items as item (item.label)}
						{@const active = isActive(item, page.url.pathname)}
						<li>
							<a
								href={navHref(item)}
								aria-current={active ? 'page' : undefined}
								class={cn(
									'flex h-9 items-center rounded-full px-3.5 text-sm font-medium transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30',
									active
										? 'bg-foreground text-background'
										: 'text-muted-foreground hover:bg-accent hover:text-foreground'
								)}
							>
								{item.label}
							</a>
						</li>
					{/each}
				</ul>
			</nav>

			<div class="ml-auto flex items-center gap-1">
				<Button variant="ghost" size="icon" aria-label={de.nav.toggleTheme} title={de.nav.toggleTheme} onclick={toggleMode}>
					<Sun class="dark:hidden" />
					<Moon class="hidden dark:block" />
				</Button>

				<DropdownMenu.Root>
					<DropdownMenu.Trigger
						class="rounded-full outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30"
						aria-label={user.display_name}
					>
						<Avatar name={user.display_name} />
					</DropdownMenu.Trigger>
					<DropdownMenu.Portal>
						<DropdownMenu.Content
							align="end"
							sideOffset={8}
							class="z-50 w-64 rounded-2xl bg-popover p-1.5 text-popover-foreground shadow-raised outline-none"
						>
							<div class="flex items-center gap-3 px-2.5 pt-2 pb-3">
								<Avatar name={user.display_name} />
								<div class="min-w-0">
									<p class="truncate text-sm font-semibold">{user.display_name}</p>
									<p class="truncate text-xs text-muted-foreground">{user.email}</p>
								</div>
							</div>
							<DropdownMenu.Separator class="-mx-1.5 my-1 h-px bg-border" />
							<DropdownMenu.Item class={menuItemClass}>
								{#snippet child({ props })}
									<a href={resolve('settings/account')} {...props}>
										<UserRound />
										{de.nav.account}
									</a>
								{/snippet}
							</DropdownMenu.Item>
							<DropdownMenu.Item class={menuItemClass}>
								{#snippet child({ props })}
									<a href={resolve('settings/privacy')} {...props}>
										<Shield />
										{de.nav.privacy}
									</a>
								{/snippet}
							</DropdownMenu.Item>
							<DropdownMenu.Separator class="-mx-1.5 my-1 h-px bg-border" />
							<DropdownMenu.Item class={menuItemClass} onSelect={() => logoutForm?.requestSubmit()}>
								<LogOut />
								{de.nav.logout}
							</DropdownMenu.Item>
						</DropdownMenu.Content>
					</DropdownMenu.Portal>
				</DropdownMenu.Root>
			</div>
		</div>
	</header>

	<main class="mx-auto w-full max-w-6xl px-4 pt-6 pb-28 md:px-6 md:pt-10 md:pb-16">
		{@render children()}
	</main>

	<nav
		class="pb-safe fixed inset-x-0 bottom-0 z-30 border-t border-border/70 bg-background/85 backdrop-blur-xl md:hidden"
		aria-label={de.nav.menu}
	>
		<ul class="mx-auto grid max-w-md grid-cols-5 px-2">
			{#each items as item (item.label)}
				{@const active = isActive(item, page.url.pathname)}
				<li>
					<a
						href={navHref(item)}
						aria-current={active ? 'page' : undefined}
						class={cn(
							'flex h-16 flex-col items-center justify-center gap-1 text-[11px] font-medium outline-none',
							active ? 'text-foreground' : 'text-muted-foreground'
						)}
					>
						<span
							class={cn(
								'flex h-7 w-12 items-center justify-center rounded-full transition-colors',
								active && 'bg-primary/12 text-primary'
							)}
						>
							<item.icon class="size-[18px]" />
						</span>
						<span class="max-w-full truncate">{item.label}</span>
					</a>
				</li>
			{/each}
		</ul>
	</nav>
</div>
