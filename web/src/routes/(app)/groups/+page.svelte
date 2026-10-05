<script lang="ts">
	import { resolve } from '$app/paths';
	import { enhance } from '$app/forms';
	import { ChevronRight, Users } from '@lucide/svelte';
	import EmptyState from '#lib/components/EmptyState.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import Avatar from '#lib/components/ui/avatar.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import { de } from '#lib/i18n/de.js';
	import { roleLabel } from '#lib/roles.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();
</script>

<svelte:head>
	<title>{de.pages.groups.title} · {de.app.name}</title>
</svelte:head>

<PageHeader title={de.pages.groups.title} />

<div class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
	<section>
		{#if data.groups.length === 0}
			<EmptyState icon={Users} title={de.pages.groups.empty} description={de.empty.noData} />
		{:else}
			<Card class="overflow-hidden">
				<ul class="divide-y divide-border/60">
					{#each data.groups as group (group.id)}
						<li>
							<a
								href={resolve('/(app)/groups/[id]', { id: group.id })}
								class="group flex items-center gap-3.5 px-5 py-4 transition-colors outline-none hover:bg-muted/40 focus-visible:bg-muted/40"
							>
								<Avatar name={group.name} class="rounded-lg" />
								<div class="min-w-0 flex-1">
									<p class="truncate font-medium">{group.name}</p>
									<p class="text-xs text-muted-foreground">
										{group.member_count}
										{de.pages.groups.members}
									</p>
								</div>
								<Badge variant={group.role === 'member' ? 'secondary' : 'default'}>{roleLabel(group.role)}</Badge>
								<ChevronRight
									class="size-4 shrink-0 text-muted-foreground/60 transition-transform group-hover:translate-x-0.5 group-hover:text-foreground"
								/>
							</a>
						</li>
					{/each}
				</ul>
			</Card>
		{/if}
	</section>

	<aside class="space-y-4">
		<Card>
			<CardHeader>
				<CardTitle>{de.pages.groups.create}</CardTitle>
			</CardHeader>
			<CardContent>
				<form method="POST" action="?/create" class="space-y-3" use:enhance>
					<div class="space-y-1.5">
						<Label for="name">{de.pages.groups.groupName}</Label>
						<Input id="name" name="name" required minlength={2} maxlength={60} />
					</div>
					{#if form?.createError}
						<p class="text-sm text-destructive">{form.createError}</p>
					{/if}
					<Button type="submit" class="w-full">{de.pages.groups.create}</Button>
				</form>
			</CardContent>
		</Card>

		<Card>
			<CardHeader>
				<CardTitle>{de.pages.groups.joinByCode}</CardTitle>
			</CardHeader>
			<CardContent>
				<form method="POST" action="?/join" class="space-y-3" use:enhance>
					<div class="space-y-1.5">
						<Label for="invite_code">{de.pages.groups.inviteCode}</Label>
						<Input id="invite_code" name="invite_code" required autocomplete="off" class="font-mono" />
					</div>
					{#if form?.joinError}
						<p class="text-sm text-destructive">{form.joinError}</p>
					{/if}
					<Button type="submit" variant="outline" class="w-full">{de.pages.join.confirm}</Button>
				</form>
			</CardContent>
		</Card>
	</aside>
</div>
