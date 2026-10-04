const FALLBACK = "UTC";

/** IANA timezone from the browser (e.g. Europe/Vienna). */
export function readBrowserTimezone(fallback = FALLBACK): string {
  if (typeof Intl === "undefined") return fallback;
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || fallback;
  } catch {
    return fallback;
  }
}
