import type { RequestHandler } from "./$types";
import { getServerEnv } from "#lib/server/env.js";

export const GET: RequestHandler = () => {
  const { androidPackageName, androidCertSha256Fingerprints } = getServerEnv();
  return Response.json([
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: androidPackageName,
        sha256_cert_fingerprints: androidCertSha256Fingerprints,
      },
    },
  ]);
};
