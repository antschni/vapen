import { describe, expect, it } from "vitest";
import { healthResponse } from "./health.js";

describe("healthResponse", () => {
  it("returns plain ok", async () => {
    const res = healthResponse();
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("ok");
  });
});
