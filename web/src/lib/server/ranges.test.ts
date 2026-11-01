import { afterEach, describe, expect, it, vi } from "vitest";
import { rangeFromPreset } from "./ranges.js";

describe("rangeFromPreset", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("starts 'today' at local midnight of the user's timezone, not UTC", () => {
    // 2026-11-01 00:30 in Vienna (UTC+1) is still 2026-10-31 in UTC.
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-10-31T23:30:00Z"));
    const { from, to } = rangeFromPreset("today", "Europe/Vienna");
    expect(from.getTime()).toBe(Date.parse("2026-10-31T23:00:00.000Z"));
    expect(to.getTime()).toBe(Date.parse("2026-10-31T23:30:00.000Z"));
  });

  it("covers 7 calendar days including today across a DST change", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-10-28T12:00:00Z"));
    const { from } = rangeFromPreset("7d", "Europe/Vienna");
    // 2026-10-22 00:00 CEST (UTC+2), before the switch to CET on 2026-10-25.
    expect(from.getTime()).toBe(Date.parse("2026-10-21T22:00:00.000Z"));
  });

  it("falls back to 7 days for invalid custom dates instead of throwing", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-10-28T12:00:00Z"));
    const { from, to } = rangeFromPreset("custom", "UTC", "garbage", "nope");
    expect(from.getTime()).toBe(Date.parse("2026-10-22T00:00:00.000Z"));
    expect(to.getTime()).toBe(Date.parse("2026-10-28T12:00:00.000Z"));
  });

  it("swaps a reversed custom range", () => {
    const { from, to } = rangeFromPreset(
      "custom",
      "UTC",
      "2026-10-10T00:00:00Z",
      "2026-10-01T00:00:00Z",
    );
    expect(from < to).toBe(true);
  });
});
