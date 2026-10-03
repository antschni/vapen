<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/stores';
	import type { SessionUser } from '$lib/session-user';
	import { de } from '$lib/i18n/de';
	import Button from '$lib/components/ui/button.svelte';
	import { ModeWatcher, toggleMode } from 'mode-watcher';
	import {
		LayoutDashboard,
		BarChart3,
		Smartphone,
		Users,
		Shield,
		UserCircle,
		LogOut,
		Menu,
		Moon,
		Sun
	} from '@lucide/svelte';
	import { cn } from '$lib/utils';

	let { children, user }: { children: import('svelte').Snippet; user: SessionUser } = $props();

	let mobileOpen = $state(false);

	const nav: {
		href:
			| '/'
			| '/usage'
			| '/devices'
			| '/groups'
			| '/settings/privacy'
			| '/settings/account';
		label: string;
		icon: typeof LayoutDashboard;
	}[] = [
		{ href: '/', label: de.nav.overview, icon: LayoutDashboard },
		{ href: '/usage', label: de.nav.usage, icon: BarChart3 },
		{ href: '/devices', label: de.nav.devices, icon: Smartphone },
		{ href: '/groups', label: de.nav.groups, icon: Users },
		{ href: '/settings/privacy', label: de.nav.privacy, icon: Shield },
		{ href: '/settings/account', label: de.nav.account, icon: UserCircle }
	];

	function isActive(href: string, pathname: string): boolean {
		if (href === '/') return pathname === '/';
		return pathname === href || pathname.startsWith(href + '/');
	}
</script>

<ModeWatcher />

<div class="min-h-dvh bg-background">
	<header
		class="sticky top-0 z-40 flex h-14 items-center gap-3 border-b bg-background/95 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/60 lg:hidden"
	>
		<Button variant="ghost" size="icon" type="button" aria-label={de.nav.menu} onclick={() => (mobileOpen = !mobileOpen)}>
			<Menu class="h-5 w-5" />
		</Button>
		<span class="font-semibold">{de.app.name}</span>
		<div class="ml-auto flex items-center gap-2">
			<Button variant="ghost" size="icon" type="button" aria-label={de.nav.toggleTheme} onclick={toggleMode}>
				<Sun class="h-5 w-5 dark:hidden" />
				<Moon class="hidden h-5 w-5 dark:block" />
			</Button>
		</div>
	</header>

	<div class="flex">
		<aside
			class={cn(
				'fixed inset-y-0 left-0 z-50 flex w-64 flex-col border-r bg-card transition-transform lg:static lg:translate-x-0',
				mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
			)}
		>
			<div class="hidden h-14 items-center border-b px-6 font-semibold lg:flex">{de.app.name}</div>
			<nav class="flex flex-1 flex-col gap-1 p-3" aria-label={de.nav.settings}>
				{#each nav as item (item.href)}
					<a
						href={resolve(item.href)}
						class={cn(
							'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
							isActive(item.href, $page.url.pathname)
								? 'bg-accent text-accent-foreground'
								: 'text-muted-foreground hover:bg-accent/50 hover:text-foreground'
						)}
						onclick={() => (mobileOpen = false)}
					>
						<item.icon class="h-4 w-4 shrink-0" />
						{item.label}
					</a>
				{/each}
			</nav>
			<div class="border-t p-3">
				<p class="mb-2 truncate px-3 text-xs text-muted-foreground" title={user.email}>
					{user.display_name}
				</p>
				<div class="mb-2 hidden lg:block">
					<Button variant="ghost" size="sm" class="w-full justify-start gap-2" type="button" onclick={toggleMode}>
						<Sun class="h-4 w-4 dark:hidden" />
						<Moon class="hidden h-4 w-4 dark:block" />
						{de.nav.toggleTheme}
					</Button>
				</div>
				<form method="POST" action="/logout">
					<Button variant="outline" class="w-full justify-start gap-2" type="submit">
						<LogOut class="h-4 w-4" />
						{de.nav.logout}
					</Button>
				</form>
			</div>
		</aside>

		{#if mobileOpen}
			<button
				type="button"
				class="fixed inset-0 z-40 bg-black/40 lg:hidden"
				aria-label={de.common.close}
				onclick={() => (mobileOpen = false)}
			></button>
		{/if}

		<main class="min-h-dvh flex-1 p-4 md:p-6 lg:p-8">
			{@render children()}
		</main>
	</div>
</div>
