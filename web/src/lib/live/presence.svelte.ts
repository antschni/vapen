import { derivePresenceStatus, type PresenceStatus } from "#lib/live/status.js";

export type LiveMember = {
  user_id: string;
  display_name: string;
  vaping_since: string | null;
  last_puff_at: string | null;
  last_puff_duration_ms: number | null;
  status: PresenceStatus;
};

type SnapshotPayload = {
  members: Array<{
    user_id: string;
    display_name: string;
    vaping_since: string | null;
    last_puff_at: string | null;
    last_puff_duration_ms: number | null;
  }>;
};

type MemberUpdatePayload = SnapshotPayload["members"][number];
type MemberRemovedPayload = { user_id: string };

const MIN_BACKOFF_MS = 1000;
const MAX_BACKOFF_MS = 30_000;
const TICK_MS = 2000;

function memberFromPayload(m: MemberUpdatePayload, nowMs: number): LiveMember {
  return {
    ...m,
    status: derivePresenceStatus(m.vaping_since, m.last_puff_at, nowMs),
  };
}

export class LivePresence {
  readonly groupId: string;

  members = $state<LiveMember[]>([]);
  connected = $state(false);
  error = $state<string | null>(null);

  #es: EventSource | null = null;
  #backoffMs = MIN_BACKOFF_MS;
  #reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  #tickTimer: ReturnType<typeof setInterval> | null = null;
  #paused = false;
  #destroyed = false;
  #onVisibility: (() => void) | null = null;

  constructor(groupId: string) {
    this.groupId = groupId;
  }

  connect(): void {
    if (this.#destroyed) return;
    this.#clearReconnect();
    this.#closeEventSource();
    const url = `/stream/groups/${this.groupId}`;
    try {
      this.#es = new EventSource(url);
    } catch (e) {
      this.error = e instanceof Error ? e.message : "EventSource failed";
      this.#scheduleReconnect();
      return;
    }

    this.#es.addEventListener("open", () => {
      this.connected = true;
      this.error = null;
      this.#backoffMs = MIN_BACKOFF_MS;
    });

    this.#es.addEventListener("error", () => {
      this.connected = false;
      this.#closeEventSource();
      if (!this.#paused && !this.#destroyed) {
        this.#scheduleReconnect();
      }
    });

    this.#es.addEventListener("snapshot", (ev) => {
      this.#applySnapshot(ev as MessageEvent<string>);
    });
    this.#es.addEventListener("member_update", (ev) => {
      this.#applyMemberUpdate(ev as MessageEvent<string>);
    });
    this.#es.addEventListener("member_removed", (ev) => {
      this.#applyMemberRemoved(ev as MessageEvent<string>);
    });

    if (!this.#tickTimer) {
      this.#tickTimer = setInterval(() => this.#retickStatuses(), TICK_MS);
    }

    if (!this.#onVisibility && typeof document !== "undefined") {
      this.#onVisibility = () => {
        if (document.hidden) {
          this.#paused = true;
          this.#closeEventSource();
          this.connected = false;
        } else {
          this.#paused = false;
          this.connect();
        }
      };
      document.addEventListener("visibilitychange", this.#onVisibility);
    }
  }

  destroy(): void {
    this.#destroyed = true;
    this.#clearReconnect();
    this.#closeEventSource();
    if (this.#tickTimer) {
      clearInterval(this.#tickTimer);
      this.#tickTimer = null;
    }
    if (this.#onVisibility && typeof document !== "undefined") {
      document.removeEventListener("visibilitychange", this.#onVisibility);
      this.#onVisibility = null;
    }
    this.connected = false;
  }

  #applySnapshot(ev: MessageEvent<string>): void {
    try {
      const data = JSON.parse(ev.data) as SnapshotPayload;
      const now = Date.now();
      this.members = data.members.map((m) => memberFromPayload(m, now));
    } catch {
      /* ignore malformed */
    }
  }

  #applyMemberUpdate(ev: MessageEvent<string>): void {
    try {
      const data = JSON.parse(ev.data) as MemberUpdatePayload;
      const now = Date.now();
      const updated = memberFromPayload(data, now);
      const idx = this.members.findIndex((m) => m.user_id === data.user_id);
      if (idx >= 0) {
        this.members[idx] = updated;
      } else {
        this.members = [...this.members, updated];
      }
    } catch {
      /* ignore */
    }
  }

  #applyMemberRemoved(ev: MessageEvent<string>): void {
    try {
      const data = JSON.parse(ev.data) as MemberRemovedPayload;
      this.members = this.members.filter((m) => m.user_id !== data.user_id);
    } catch {
      /* ignore */
    }
  }

  #retickStatuses(): void {
    const now = Date.now();
    this.members = this.members.map((m) => ({
      ...m,
      status: derivePresenceStatus(m.vaping_since, m.last_puff_at, now),
    }));
  }

  #scheduleReconnect(): void {
    this.#clearReconnect();
    this.#reconnectTimer = setTimeout(() => {
      this.#reconnectTimer = null;
      this.connect();
      this.#backoffMs = Math.min(this.#backoffMs * 2, MAX_BACKOFF_MS);
    }, this.#backoffMs);
  }

  #clearReconnect(): void {
    if (this.#reconnectTimer) {
      clearTimeout(this.#reconnectTimer);
      this.#reconnectTimer = null;
    }
  }

  #closeEventSource(): void {
    if (this.#es) {
      this.#es.close();
      this.#es = null;
    }
  }
}
