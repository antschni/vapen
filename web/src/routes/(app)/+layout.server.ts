import { error, fail } from "@sveltejs/kit";
import type { Actions, LayoutServerLoad } from "./$types";
import { timezoneSchema } from "#lib/server/form-schemas.js";

export const load: LayoutServerLoad = async ({ locals }) => {
  if (!locals.user || !locals.api) {
    error(401, "Unauthorized");
  }

  const { data, error: apiError } = await locals.api.GET("/groups");
  if (apiError) {
    error(500, "Failed to load groups");
  }

  return {
    user: locals.user,
    groups: data ?? [],
  };
};

export const actions: Actions = {
  syncTimezone: async ({ request, locals }) => {
    const form = await request.formData();
    const parsed = timezoneSchema.safeParse({
      timezone: form.get("timezone"),
    });
    if (!parsed.success) return fail(400);
    const { error: apiError, response } = await locals.api!.PATCH("/me", {
      body: { timezone: parsed.data.timezone },
    });
    if (apiError) return fail(response.status);
    return { ok: true };
  },
};
