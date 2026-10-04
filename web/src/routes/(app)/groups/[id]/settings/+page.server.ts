import { error, fail, redirect } from "@sveltejs/kit";
import QRCode from "qrcode";
import type { Actions, PageServerLoad } from "./$types";
import { groupNameSchema, memberRoleSchema } from "#lib/server/form-schemas.js";
import { messageFromApiProblem } from "#lib/server/api-problem.js";
import { getServerEnv } from "#lib/server/env.js";
import { de } from "#lib/i18n/de.js";
async function callerGroupRole(
  locals: App.Locals,
  groupId: string,
): Promise<"owner" | "admin" | "member" | null> {
  const { data } = await locals.api!.GET("/groups");
  const row = data?.find((g) => g.id === groupId);
  return row?.role ?? null;
}

export const load: PageServerLoad = async ({ locals, parent, params }) => {
  const { groups } = await parent();
  const membership = groups.find((g) => g.id === params.id);
  if (
    !membership ||
    (membership.role !== "owner" && membership.role !== "admin")
  ) {
    error(403, de.errors.forbidden);
  }

  const {
    data,
    error: apiError,
    response,
  } = await locals.api!.GET("/groups/{id}", {
    params: { path: { id: params.id } },
  });
  if (apiError || !data) {
    error(response.status === 404 ? 404 : 500, de.errors.notFound);
  }

  const { origin } = getServerEnv();
  const inviteCode = data.invite_code ?? "";
  const inviteUrl = inviteCode
    ? `${origin.replace(/\/$/, "")}/join/${inviteCode}`
    : "";
  const qrDataUrl = inviteUrl
    ? await QRCode.toDataURL(inviteUrl, { margin: 2, width: 256 })
    : "";

  return {
    group: data,
    role: membership.role,
    inviteUrl,
    qrDataUrl,
  };
};

export const actions: Actions = {
  rename: async ({ request, locals, params }) => {
    const form = await request.formData();
    const parsed = groupNameSchema.safeParse({ name: form.get("name") });
    if (!parsed.success)
      return fail(400, { error: de.errors.validationFailed });
    const { error: apiError, response } = await locals.api!.PATCH(
      "/groups/{id}",
      {
        params: { path: { id: params.id } },
        body: parsed.data,
      },
    );
    if (apiError)
      return fail(response.status, { error: messageFromApiProblem(apiError) });
    return { success: true };
  },
  rotate: async ({ locals, params }) => {
    const { error: apiError, response } = await locals.api!.POST(
      "/groups/{id}/invite/rotate",
      {
        params: { path: { id: params.id } },
      },
    );
    if (apiError)
      return fail(response.status, { error: messageFromApiProblem(apiError) });
    return { rotated: true };
  },
  leave: async ({ locals, params }) => {
    const { error: apiError, response } = await locals.api!.POST(
      "/groups/{id}/leave",
      {
        params: { path: { id: params.id } },
      },
    );
    if (apiError)
      return fail(response.status, { error: messageFromApiProblem(apiError) });
    redirect(303, "/groups");
  },
  deleteGroup: async ({ locals, params }) => {
    const role = await callerGroupRole(locals, params.id);
    if (role !== "owner") return fail(403, { error: de.errors.forbidden });
    const { error: apiError, response } = await locals.api!.DELETE(
      "/groups/{id}",
      {
        params: { path: { id: params.id } },
      },
    );
    if (apiError)
      return fail(response.status, { error: messageFromApiProblem(apiError) });
    redirect(303, "/groups");
  },
  removeMember: async ({ request, locals, params }) => {
    const userId = (await request.formData()).get("user_id")?.toString();
    if (!userId) return fail(400, { error: de.errors.validationFailed });
    const { error: apiError, response } = await locals.api!.DELETE(
      "/groups/{id}/members/{user_id}",
      {
        params: { path: { id: params.id, user_id: userId } },
      },
    );
    if (apiError)
      return fail(response.status, { error: messageFromApiProblem(apiError) });
    return { success: true };
  },
  setRole: async ({ request, locals, params }) => {
    const role = await callerGroupRole(locals, params.id);
    if (role !== "owner") return fail(403, { error: de.errors.forbidden });
    const form = await request.formData();
    const userId = form.get("user_id")?.toString();
    const parsed = memberRoleSchema.safeParse(form.get("role"));
    if (!userId || !parsed.success)
      return fail(400, { error: de.errors.validationFailed });
    const { error: apiError, response } = await locals.api!.PATCH(
      "/groups/{id}/members/{user_id}",
      {
        params: { path: { id: params.id, user_id: userId } },
        body: { role: parsed.data },
      },
    );
    if (apiError)
      return fail(response.status, { error: messageFromApiProblem(apiError) });
    return { success: true };
  },
};
