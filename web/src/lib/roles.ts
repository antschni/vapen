import { de } from "#lib/i18n/de.js";

export function roleLabel(role: string): string {
  if (role === "owner") return de.pages.groups.roleOwner;
  if (role === "admin") return de.pages.groups.roleAdmin;
  return de.pages.groups.roleMember;
}
