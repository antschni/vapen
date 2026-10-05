<script lang="ts">
	import { resolve } from '$app/paths';
	import { enhance } from '$app/forms';
	import EmptyState from '#lib/components/EmptyState.svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import Label from '#lib/components/ui/label.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import { de } from '#lib/i18n/de.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	function roleLabel(role: string): string {
		if (role === 'owner') return de.pages.groups.roleOwner;
		if (role === 'admin') return de.pages.groups.roleAdmin;
		return de.pages.groups.roleMember;
	}
</script>

<svelte:head>
	<title>{de.pages.groups.title} · {de.app.name}</title>
</svelte:head>

<PageHeader title={de.pages.groups.title} />

<div class="grid gap-6 lg:grid-cols-2">
	<Card>
		<CardHeader>
			<CardTitle>{de.pages.groups.create}</CardTitle>
		</CardHeader>
		<CardContent>
			<form method="POST" action="?/create" class="space-y-3" use:enhance>
				<div class="space-y-2">
					<Label for="name">{de.pages.groups.groupName}</Label>
					<Input id="name" name="name" required minlength={2} maxlength={60} />
				</div>
				{#if form?.createError}
					<p class="text-sm text-destructive">{form.createError}</p>
				{/if}
				<Button type="submit">{de.pages.groups.create}</Button>
			</form>
		</CardContent>
	</Card>

	<Card>
		<CardHeader>
			<CardTitle>{de.pages.groups.joinByCode}</CardTitle>
		</CardHeader>
		<CardContent>
			<form method="POST" action="?/join" class="space-y-3" use:enhance>
				<div class="space-y-2">
					<Label for="invite_code">{de.pages.groups.inviteCode}</Label>
					<Input id="invite_code" name="invite_code" required autocomplete="off" />
				</div>
				{#if form?.joinError}
					<p class="text-sm text-destructive">{form.joinError}</p>
				{/if}
				<Button type="submit" variant="secondary">{de.pages.join.confirm}</Button>
			</form>
		</CardContent>
	</Card>
</div>

{#if data.groups.length === 0}
	<div class="mt-8">
		<EmptyState title={de.pages.groups.empty} description={de.empty.noData} />
	</div>
{:else}
	<ul class="mt-8 space-y-3">
		{#each data.groups as group (group.id)}
			<li>
				<a
					href={resolve('/(app)/groups/[id]', { id: group.id })}
					class="flex items-center justify-between rounded-xl border border-border bg-card p-4 shadow-sm transition-colors hover:bg-accent/30 hover:shadow-md"
				>
					<div>
						<p class="font-medium">{group.name}</p>
						<p class="text-xs text-muted-foreground">
							{group.member_count} {de.pages.groups.members}
						</p>
					</div>
					<Badge variant="secondary">{roleLabel(group.role)}</Badge>
				</a>
			</li>
		{/each}
	</ul>
{/if}
