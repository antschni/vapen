import { fail, redirect } from "@sveltejs/kit";
import type { Actions, PageServerLoad } from "./$types";
import {
  changePasswordSchema,
  deleteAccountSchema,
  profileSchema,
} from "#lib/server/form-schemas.js";
import { messageFromApiProblem } from "#lib/server/api-problem.js";
import { clearTokenCookies } from "#lib/server/cookies.js";
import { de } from "#lib/i18n/de.js";

export const load: PageServerLoad = async ({ locals }) => {
  const { data } = await locals.api!.GET("/me");
  return { profile: data ?? null };
};

export const actions: Actions = {
  profile: async ({ request, locals }) => {
    const form = await request.formData();
    const parsed = profileSchema.safeParse({
      display_name: form.get("display_name"),
    });
    if (!parsed.success)
      return fail(400, { profileError: de.errors.validationFailed });
    const { error, response } = await locals.api!.PATCH("/me", {
      body: parsed.data,
    });
    if (error)
      return fail(response.status, {
        profileError: messageFromApiProblem(error),
      });
    return { profileSaved: true };
  },
  password: async ({ request, locals }) => {
    const form = await request.formData();
    const parsed = changePasswordSchema.safeParse({
      current_password: form.get("current_password"),
      new_password: form.get("new_password"),
    });
    if (!parsed.success)
      return fail(400, { passwordError: de.errors.validationFailed });
    const { error, response } = await locals.api!.POST("/me/password", {
      body: parsed.data,
    });
    if (error)
      return fail(response.status, {
        passwordError: messageFromApiProblem(error),
      });
    return { passwordSaved: true };
  },
  delete: async (event) => {
    const form = await event.request.formData();
    const parsed = deleteAccountSchema.safeParse({
      password: form.get("password"),
    });
    if (!parsed.success)
      return fail(400, { deleteError: de.errors.validationFailed });
    const { error, response } = await event.locals.api!.DELETE("/me", {
      body: parsed.data,
    });
    if (error)
      return fail(response.status, {
        deleteError: messageFromApiProblem(error),
      });
    clearTokenCookies(event.cookies);
    redirect(303, "/login");
  },
};
