import { defineEnvVars } from "@sveltejs/kit/env";

export const variables = defineEnvVars({
  API_INTERNAL_URL: { schema: (input) => input ?? "" },
  ORIGIN: { schema: (input) => input ?? "" },
  COOKIE_SECURE: { schema: (input) => input ?? "" },
  PROTOCOL_HEADER: { schema: (input) => input ?? "" },
  HOST_HEADER: { schema: (input) => input ?? "" },
  ADDRESS_HEADER: { schema: (input) => input ?? "" },
  XFF_DEPTH: { schema: (input) => input ?? "" },
  ANDROID_PACKAGE_NAME: { schema: (input) => input ?? "" },
  ANDROID_CERT_SHA256_FINGERPRINTS: { schema: (input) => input ?? "" },
});
