import type { RequestHandler } from "@sveltejs/kit";
import { healthResponse } from "#lib/server/health.js";

/** Alias for orchestrators that expect `/healthz` (same as the Go API). */
export const GET: RequestHandler = () => healthResponse();
export const HEAD: RequestHandler = () => healthResponse();
