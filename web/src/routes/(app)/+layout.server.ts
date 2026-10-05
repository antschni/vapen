import { error } from "@sveltejs/kit";
import type { LayoutServerLoad } from "./$types";

export const load: LayoutServerLoad = async ({ locals }) => {
  if (!locals.user || !locals.api) {
    error(401, "Unauthorized");
  }

  const [groupsRes, devicesRes] = await Promise.all([
    locals.api.GET("/groups"),
    locals.api.GET("/devices"),
  ]);
  if (groupsRes.error) {
    error(500, "Failed to load groups");
  }

  const { isElfbarBridgeLive } = await import("#lib/live/elfbar-bridge.js");

  return {
    user: locals.user,
    groups: groupsRes.data ?? [],
    elfbarBridgeLive: isElfbarBridgeLive(devicesRes.data ?? []),
  };
};
