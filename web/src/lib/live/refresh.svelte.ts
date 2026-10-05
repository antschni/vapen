export type LiveRefreshState = {
	tick: number;
};

let tick = $state(0);

export function getLiveRefresh(): LiveRefreshState {
	return { tick };
}

export function liveRefreshEnd(): void {
	tick += 1;
}
