export function csvEscape(value: string): string {
  if (/[",\n\r]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
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
