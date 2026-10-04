import { de } from "#lib/i18n/de.js";

/** English `detail` strings from the Go API → German UI copy. */
const DETAIL_MESSAGES: Record<string, string> = {
  "password must be 12 to 128 characters": de.validation.passwordMin,
  "new_password must be 12 to 128 characters": de.validation.passwordMin,
  "invalid timezone": de.validation.timezone,
};

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
  detail?: string,
): string {
  if (detail && DETAIL_MESSAGES[detail]) {
    return DETAIL_MESSAGES[detail];
  }
  if (!code) return fallback ?? de.errors.generic;
  return CODE_MESSAGES[code] ?? fallback ?? de.errors.generic;
}
