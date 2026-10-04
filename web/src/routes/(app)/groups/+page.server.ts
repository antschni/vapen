import { fail, redirect } from "@sveltejs/kit";
import type { Actions, PageServerLoad } from "./$types";
import { groupNameSchema, joinCodeSchema } from "#lib/server/form-schemas.js";
import { messageFromApiProblem } from "#lib/server/api-problem.js";
import { de } from "#lib/i18n/de.js";

export const load: PageServerLoad = async ({ parent }) => {
  const { groups } = await parent();
  return { groups };
};

export const actions: Actions = {
  create: async ({ request, locals }) => {
    const form = await request.formData();
    const parsed = groupNameSchema.safeParse({ name: form.get("name") });
    if (!parsed.success) {
      return fail(400, { createError: de.errors.validationFailed });
    }
    const { data, error, response } = await locals.api!.POST("/groups", {
      body: parsed.data,
    });
    if (error || !data) {
      return fail(response.status, {
        createError: messageFromApiProblem(error),
      });
    }
    redirect(303, `/groups/${data.id}`);
  },
  join: async ({ request, locals }) => {
    const form = await request.formData();
    const parsed = joinCodeSchema.safeParse({
      invite_code: form.get("invite_code"),
    });
    if (!parsed.success) {
      return fail(400, { joinError: de.errors.validationFailed });
    }
    const { data, error, response } = await locals.api!.POST("/groups/join", {
      body: parsed.data,
    });
    if (error || !data) {
      return fail(response.status, {
        joinError: messageFromApiProblem(error, de.pages.join.invalidCode),
      });
    }
    redirect(303, `/groups/${data.id}`);
  },
};
