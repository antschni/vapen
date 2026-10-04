import { error } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";

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
