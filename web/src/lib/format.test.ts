import { describe, expect, it } from "vitest";
import { formatDurationMs, formatNumber } from "./format";

describe("formatDurationMs", () => {
  it("keeps fractional seconds exact", () => {
    expect(formatDurationMs(2300)).toBe("2,3 s");
    expect(formatDurationMs(1500)).toBe("1,5 s");
    expect(formatDurationMs(1234)).toBe("1,234 s");
    expect(formatDurationMs(1000)).toBe("1 s");
  });

  it("formats minutes", () => {
    expect(formatDurationMs(72_000)).toBe("1 Min. 12 s");
    expect(formatDurationMs(72_300)).toBe("1 Min. 12,3 s");
  });
});

describe("formatNumber", () => {
  it("uses German grouping", () => {
    expect(formatNumber(1234)).toBe("1.234");
  });
});
