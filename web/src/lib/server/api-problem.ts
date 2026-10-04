import type { components } from "#lib/api/schema.d.ts";
import { mapProblemCodeToGerman } from "#lib/server/problems.js";

export function messageFromApiProblem(
  error: unknown,
  fallback?: string,
): string {
  const problem = error as components["schemas"]["Problem"] | undefined;
  return mapProblemCodeToGerman(problem?.code, fallback);
}
