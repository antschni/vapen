import type { PageServerLoad } from "./$types";

export const load: PageServerLoad = async ({ locals }) => {
  const { data, error } = await locals.api!.GET("/devices");
  if (error) {
    return { devices: [] };
  }
  return { devices: data ?? [] };
};
