const FORMULA_PREFIXES = ["=", "+", "-", "@", "\t", "\r"];
const QUOTE_TRIGGERS = ['"', ",", "\n", "\r"];

export function csvEscape(value: string): string {
  // Spreadsheet apps evaluate cells starting with these as formulas.
  const safe = FORMULA_PREFIXES.some((p) => value.startsWith(p))
    ? `'${value}`
    : value;
  if (QUOTE_TRIGGERS.some((c) => safe.includes(c))) {
    return `"${safe.replaceAll('"', '""')}"`;
  }
  return safe;
}

export function puffRowToCsv(
  id: string,
  startedAt: string,
  durationMs: number,
  deviceId: string,
  source: string,
): string {
  return [id, startedAt, String(durationMs), deviceId, source]
    .map(csvEscape)
    .join(",");
}
