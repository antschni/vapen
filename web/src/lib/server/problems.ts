import { de } from "#lib/i18n/de.js";

const CODE_MESSAGES: Record<string, string> = {
  validation_failed: de.errors.validationFailed,
  invalid_credentials: de.errors.invalidCredentials,
  unauthorized: de.errors.unauthorized,
  token_expired: de.errors.tokenExpired,
  forbidden: de.errors.forbidden,
  not_found: de.errors.notFound,
  conflict: de.errors.conflict,
  rate_limited: de.errors.rateLimited,
  payload_too_large: de.errors.payloadTooLarge,
  internal: de.errors.internal,
};

export function mapProblemCodeToGerman(
  code: string | undefined,
  fallback?: string,
): string {
  if (!code) return fallback ?? de.errors.generic;
  return CODE_MESSAGES[code] ?? fallback ?? de.errors.generic;
}
