import { fail, redirect } from "@sveltejs/kit";
import type { Actions, PageServerLoad } from "./$types";
import { messageFromApiProblem } from "#lib/server/api-problem.js";
import { de } from "#lib/i18n/de.js";

export const load: PageServerLoad = async ({ locals, params, url }) => {
  const code = params.code;
  if (!locals.user) {
    const redirectTo = validateJoinRedirect(url.pathname);
    redirect(303, `/login?redirectTo=${encodeURIComponent(redirectTo)}`);
  }
  return { code };
};

export const actions: Actions = {
  default: async ({ locals, params }) => {
    const { data, error, response } = await locals.api!.POST("/groups/join", {
      body: { invite_code: params.code },
    });
    if (error || !data) {
      return fail(response.status, {
        message: messageFromApiProblem(error, de.pages.join.invalidCode),
      });
    }
    redirect(303, `/groups/${data.id}`);
  },
};

function validateJoinRedirect(path: string): string {
  if (path.startsWith("/join/") && !path.includes("//")) return path;
  return "/";
}
