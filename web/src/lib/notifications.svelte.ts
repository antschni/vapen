import { SvelteMap } from 'svelte/reactivity';

export type ToastKind = 'success' | 'error';

export type Toast = {
	id: number;
	message: string;
	kind: ToastKind;
};

let toasts = $state<Toast[]>([]);
let nextId = 1;
const timers = new SvelteMap<number, ReturnType<typeof setTimeout>>();

export function getToasts(): Toast[] {
	return toasts;
}

export function dismissToast(id: number) {
	const timer = timers.get(id);
	if (timer) clearTimeout(timer);
	timers.delete(id);
	toasts = toasts.filter((toast) => toast.id !== id);
}

export function notify(message: string, kind: ToastKind = 'success') {
	for (const existing of toasts) {
		if (existing.kind !== kind) continue;
		const timer = timers.get(existing.id);
		if (timer) clearTimeout(timer);
		timers.delete(existing.id);
	}
	const id = nextId++;
	toasts = [...toasts.filter((toast) => toast.kind !== kind), { id, message, kind }];
	timers.set(
		id,
		setTimeout(() => dismissToast(id), 3400)
	);
}
