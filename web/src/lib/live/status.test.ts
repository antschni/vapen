import { describe, expect, it } from "vitest";
import { derivePresenceStatus } from "./status";

describe("derivePresenceStatus", () => {
  const now = Date.parse("2026-10-03T12:00:00.000Z");

  it("returns vaping when vaping_since is recent", () => {
    expect(derivePresenceStatus("2026-10-03T11:59:50.000Z", null, now)).toBe(
      "vaping",
    );
  });

  it("returns active when last puff within 5 minutes", () => {
    expect(derivePresenceStatus(null, "2026-10-03T11:57:00.000Z", now)).toBe(
      "active",
    );
  });

  it("returns idle otherwise", () => {
    expect(derivePresenceStatus(null, "2026-10-03T11:00:00.000Z", now)).toBe(
      "idle",
    );
  });
});
