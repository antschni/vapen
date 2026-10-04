import { redirect } from "@sveltejs/kit";
import type { Actions } from "./$types";
import { clearTokenCookies } from "#lib/server/cookies.js";

export const actions: Actions = {
  default: async ({ cookies, locals }) => {
    if (locals.api) {
      await locals.api.POST("/auth/logout");
    }
    clearTokenCookies(cookies);
    redirect(303, "/login");
  },
};
