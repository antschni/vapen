export type LiveRefreshState = {
	refreshing: boolean;
	tick: number;
};

let refreshing = $state(false);
let tick = $state(0);

export function getLiveRefresh(): LiveRefreshState {
	return { refreshing, tick };
}

export function liveRefreshStart(): void {
	refreshing = true;
}

export function liveRefreshEnd(): void {
	refreshing = false;
	tick += 1;
}
