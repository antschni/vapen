import { error, json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { timezoneSchema } from "#lib/server/form-schemas.js";

export const POST: RequestHandler = async ({ request, locals }) => {
  if (!locals.api) error(401);

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    error(400);
  }

  const parsed = timezoneSchema.safeParse(body);
  if (!parsed.success) error(400);

  const { error: apiError, response } = await locals.api.PATCH("/me", {
    body: { timezone: parsed.data.timezone },
  });
  if (apiError) error(response.status);

  return json({ ok: true });
};
