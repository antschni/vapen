import { describe, expect, it } from "vitest";
import { csvEscape } from "./csv.js";

describe("csvEscape", () => {
  it("neutralizes spreadsheet formulas", () => {
    expect(csvEscape("=HYPERLINK(1)")).toBe("'=HYPERLINK(1)");
    expect(csvEscape("@SUM(A1)")).toBe("'@SUM(A1)");
  });

  it("quotes values with separators", () => {
    expect(csvEscape('a,"b"')).toBe('"a,""b"""');
    expect(csvEscape("plain")).toBe("plain");
  });
});
