<script lang="ts">
	import { enhance } from '$app/forms';
	import { resolve } from '$app/paths';
	import { CircleAlert, Copy, RefreshCw } from '@lucide/svelte';
	import PageHeader from '#lib/components/PageHeader.svelte';
	import Avatar from '#lib/components/ui/avatar.svelte';
	import Badge from '#lib/components/ui/badge.svelte';
	import Button from '#lib/components/ui/button.svelte';
	import Card from '#lib/components/ui/card.svelte';
	import CardContent from '#lib/components/ui/card-content.svelte';
	import CardHeader from '#lib/components/ui/card-header.svelte';
	import CardTitle from '#lib/components/ui/card-title.svelte';
	import Input from '#lib/components/ui/input.svelte';
	import { de } from '#lib/i18n/de.js';
	import { notify } from '#lib/notifications.svelte.js';
	import { roleLabel } from '#lib/roles.js';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	async function copyLink() {
		if (!data.inviteUrl) return;
		await navigator.clipboard.writeText(data.inviteUrl);
		notify(de.common.copied);
	}
</script>

<svelte:head>
	<title>{de.pages.groups.settingsTitle} · {data.group.name}</title>
</svelte:head>

<PageHeader
	title={de.pages.groups.settingsTitle}
	description={data.group.name}
	back={{ href: resolve('/(app)/groups/[id]', { id: data.group.id }), label: data.group.name }}
/>

{#if form?.error}
	<div
		class="mb-6 flex items-center gap-2.5 rounded-xl border border-destructive/20 bg-destructive/[0.06] px-4 py-3 text-sm text-destructive"
		role="alert"
	>
		<CircleAlert class="size-4 shrink-0" />
		{form.error}
	</div>
{/if}

<div class="space-y-6">
	<div class="grid items-start gap-6 lg:grid-cols-2">
		<Card>
			<CardHeader>
				<CardTitle>{de.pages.groups.groupName}</CardTitle>
			</CardHeader>
			<CardContent>
				<form method="POST" action="?/rename" class="flex gap-2" use:enhance>
					<Input name="name" value={data.group.name} required aria-label={de.pages.groups.groupName} />
					<Button type="submit">{de.common.save}</Button>
				</form>
			</CardContent>
		</Card>

		{#if data.inviteUrl}
			<Card>
				<CardHeader>
					<CardTitle>{de.pages.groups.inviteLink}</CardTitle>
				</CardHeader>
				<CardContent>
					<div class="flex flex-col gap-4 sm:flex-row sm:items-start">
						<div class="min-w-0 flex-1 space-y-3">
							<code class="block rounded-lg bg-muted px-3 py-2 font-mono text-xs break-all">{data.inviteUrl}</code>
							<div class="flex flex-wrap gap-2">
								<Button type="button" size="sm" variant="outline" onclick={copyLink}>
									<Copy />
									{de.pages.groups.copyLink}
								</Button>
								<form method="POST" action="?/rotate" use:enhance>
									<Button type="submit" size="sm" variant="ghost">
										<RefreshCw />
										{de.pages.groups.rotateCode}
									</Button>
								</form>
							</div>
						</div>
						{#if data.qrDataUrl}
							<img
								src={data.qrDataUrl}
								alt={de.pages.groups.qrAlt}
								class="size-32 shrink-0 self-center rounded-lg border border-border/70 bg-white p-1.5"
							/>
						{/if}
					</div>
				</CardContent>
			</Card>
		{/if}
	</div>

	<Card>
		<CardHeader>
			<CardTitle>{de.pages.groups.members}</CardTitle>
		</CardHeader>
		<CardContent>
			<ul class="divide-y divide-border/60">
				{#each data.group.members as member (member.user_id)}
					<li class="flex flex-wrap items-center gap-3 py-3 first:pt-0 last:pb-0">
						<Avatar name={member.display_name} size="sm" />
						<div class="flex min-w-0 flex-1 items-center gap-2">
							<span class="truncate text-sm font-medium">{member.display_name}</span>
							<Badge variant={member.role === 'member' ? 'secondary' : 'default'}>{roleLabel(member.role)}</Badge>
						</div>
						<div class="flex flex-wrap gap-1">
							{#if data.role === 'owner' && member.role !== 'owner'}
								<form method="POST" action="?/setRole" use:enhance>
									<input type="hidden" name="user_id" value={member.user_id} />
									{#if member.role === 'member'}
										<input type="hidden" name="role" value="admin" />
										<Button type="submit" size="sm" variant="ghost">{de.pages.groups.promoteAdmin}</Button>
									{:else if member.role === 'admin'}
										<input type="hidden" name="role" value="member" />
										<Button type="submit" size="sm" variant="ghost">{de.pages.groups.demoteMember}</Button>
									{/if}
								</form>
								<form method="POST" action="?/setRole" use:enhance>
									<input type="hidden" name="user_id" value={member.user_id} />
									<input type="hidden" name="role" value="owner" />
									<Button type="submit" size="sm" variant="ghost">{de.pages.groups.transferOwnership}</Button>
								</form>
							{/if}
							{#if (data.role === 'owner' || data.role === 'admin') && member.role !== 'owner'}
								<form method="POST" action="?/removeMember" use:enhance>
									<input type="hidden" name="user_id" value={member.user_id} />
									<Button type="submit" size="sm" variant="destructive-ghost">{de.pages.groups.removeMember}</Button>
								</form>
							{/if}
						</div>
					</li>
				{/each}
			</ul>
		</CardContent>
	</Card>

	<Card class="border-destructive/25">
		<div class="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
			<div>
				<p class="text-[15px] font-semibold">{de.common.dangerZone}</p>
				<p class="mt-1 text-sm text-muted-foreground">
					{data.role === 'owner' ? de.pages.groups.deleteGroupConfirm : de.pages.groups.leaveHint}
				</p>
			</div>
			{#if data.role === 'owner'}
				<form method="POST" action="?/deleteGroup" use:enhance>
					<Button type="submit" variant="destructive">{de.pages.groups.deleteGroup}</Button>
				</form>
			{:else}
				<form method="POST" action="?/leave" use:enhance>
					<Button type="submit" variant="outline">{de.pages.groups.leave}</Button>
				</form>
			{/if}
		</div>
	</Card>
</div>
