<script lang="ts">
	import { enhance } from '$app/forms';
	import Button from '$lib/components/ui/button.svelte';
	import Card from '$lib/components/ui/card.svelte';
	import CardContent from '$lib/components/ui/card-content.svelte';
	import CardHeader from '$lib/components/ui/card-header.svelte';
	import CardTitle from '$lib/components/ui/card-title.svelte';
	import Input from '$lib/components/ui/input.svelte';
	import Badge from '$lib/components/ui/badge.svelte';
	import { resolve } from '$app/paths';
	import { de } from '$lib/i18n/de';
	import type { PageData, ActionData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	async function copyLink() {
		if (data.inviteUrl) await navigator.clipboard.writeText(data.inviteUrl);
	}

	function roleLabel(role: string): string {
		if (role === 'owner') return de.pages.groups.roleOwner;
		if (role === 'admin') return de.pages.groups.roleAdmin;
		return de.pages.groups.roleMember;
	}
</script>

<svelte:head>
	<title>{de.pages.groups.settingsTitle} · {data.group.name}</title>
</svelte:head>

<p class="text-sm text-muted-foreground">
	<a href={resolve('/(app)/groups/[id]', { id: data.group.id })} class="hover:underline"
		>{de.common.back}</a
	>
</p>
<h1 class="mt-2 text-2xl font-bold tracking-tight">{de.pages.groups.settingsTitle}</h1>

{#if form?.error}
	<p class="mt-4 text-sm text-destructive">{form.error}</p>
{/if}

<Card class="mt-6">
	<CardHeader>
		<CardTitle>{de.pages.groups.groupName}</CardTitle>
	</CardHeader>
	<CardContent>
		<form method="POST" action="?/rename" class="flex gap-2" use:enhance>
			<Input name="name" value={data.group.name} required />
			<Button type="submit">{de.common.save}</Button>
		</form>
	</CardContent>
</Card>

{#if data.inviteUrl}
	<Card class="mt-6">
		<CardHeader>
			<CardTitle>{de.pages.groups.inviteLink}</CardTitle>
		</CardHeader>
		<CardContent class="space-y-4">
			<code class="block break-all rounded border p-2 text-xs">{data.inviteUrl}</code>
			<div class="flex flex-wrap gap-2">
				<Button type="button" variant="secondary" onclick={copyLink}>{de.pages.groups.copyLink}</Button>
				<form method="POST" action="?/rotate" use:enhance>
					<Button type="submit" variant="outline">{de.pages.groups.rotateCode}</Button>
				</form>
			</div>
			{#if data.qrDataUrl}
				<img src={data.qrDataUrl} alt={de.pages.groups.qrAlt} class="mx-auto size-48 rounded border" />
			{/if}
		</CardContent>
	</Card>
{/if}

<Card class="mt-6">
	<CardHeader>
		<CardTitle>{de.pages.groups.members}</CardTitle>
	</CardHeader>
	<CardContent class="space-y-3">
		{#each data.group.members as member (member.user_id)}
			<div class="flex flex-wrap items-center justify-between gap-2 rounded border p-3">
				<div>
					<span class="font-medium">{member.display_name}</span>
					<Badge variant="secondary" class="ml-2">{roleLabel(member.role)}</Badge>
				</div>
				<div class="flex flex-wrap gap-2">
					{#if data.role === 'owner' && member.role !== 'owner'}
						<form method="POST" action="?/setRole" class="flex gap-1" use:enhance>
							<input type="hidden" name="user_id" value={member.user_id} />
							{#if member.role === 'member'}
								<input type="hidden" name="role" value="admin" />
								<Button type="submit" size="sm" variant="outline">{de.pages.groups.promoteAdmin}</Button>
							{:else if member.role === 'admin'}
								<input type="hidden" name="role" value="member" />
								<Button type="submit" size="sm" variant="outline">{de.pages.groups.demoteMember}</Button>
							{/if}
						</form>
						<form method="POST" action="?/setRole" use:enhance>
							<input type="hidden" name="user_id" value={member.user_id} />
							<input type="hidden" name="role" value="owner" />
							<Button type="submit" size="sm" variant="outline">{de.pages.groups.transferOwnership}</Button>
						</form>
					{/if}
					{#if (data.role === 'owner' || data.role === 'admin') && member.role !== 'owner'}
						<form method="POST" action="?/removeMember" use:enhance>
							<input type="hidden" name="user_id" value={member.user_id} />
							<Button type="submit" size="sm" variant="destructive">{de.pages.groups.removeMember}</Button>
						</form>
					{/if}
				</div>
			</div>
		{/each}
	</CardContent>
</Card>

<div class="mt-6 flex flex-wrap gap-3">
	{#if data.role !== 'owner'}
		<form method="POST" action="?/leave" use:enhance>
			<Button type="submit" variant="outline">{de.pages.groups.leave}</Button>
		</form>
	{/if}
	{#if data.role === 'owner'}
		<form method="POST" action="?/deleteGroup" use:enhance>
			<Button type="submit" variant="destructive">{de.pages.groups.deleteGroup}</Button>
		</form>
	{/if}
</div>
