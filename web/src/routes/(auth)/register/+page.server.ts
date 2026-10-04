import { fail, redirect } from "@sveltejs/kit";
import type { Actions, PageServerLoad } from "./$types";
import { createPublicApiClient } from "#lib/server/api.js";
import { setTokenCookies } from "#lib/server/cookies.js";
import { getClientAddress } from "#lib/server/env.js";
import { validateRedirectTo } from "#lib/server/redirect.js";
import { registerSchema } from "#lib/server/auth-schemas.js";
import { messageFromApiProblem } from "#lib/server/api-problem.js";
import { de } from "#lib/i18n/de.js";

export const load: PageServerLoad = async ({ url }) => {
  return {
    redirectTo: validateRedirectTo(url.searchParams.get("redirectTo")),
  };
};

export const actions: Actions = {
  default: async (event) => {
    const form = await event.request.formData();
    const parsed = registerSchema.safeParse({
      email: form.get("email"),
      password: form.get("password"),
      display_name: form.get("display_name"),
      timezone: form.get("timezone"),
    });

    if (!parsed.success) {
      const fieldErrors = parsed.error.flatten().fieldErrors;
      const firstFieldMessage = Object.values(fieldErrors)
        .flat()
        .find((m): m is string => typeof m === "string" && m.length > 0);
      return fail(400, {
        message: firstFieldMessage ?? de.errors.validationFailed,
        fieldErrors,
      });
    }

    const api = createPublicApiClient(getClientAddress(event));
    const { data, error, response } = await api.POST("/auth/register", {
      body: parsed.data,
    });

    if (error || !data) {
      return fail(response.status >= 500 ? 500 : 400, {
        message: messageFromApiProblem(error),
        fieldErrors: {},
      });
    }

    setTokenCookies(event.cookies, data);
    const target =
      validateRedirectTo(event.url.searchParams.get("redirectTo")) ??
      validateRedirectTo(form.get("redirectTo")?.toString()) ??
      "/";
    redirect(303, target);
  },
};
