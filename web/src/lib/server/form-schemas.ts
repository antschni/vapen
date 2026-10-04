import { z } from "zod";
import { de } from "#lib/i18n/de.js";

const passwordSchema = z
  .string({ required_error: de.validation.required })
  .min(12, de.validation.passwordMin)
  .max(128, de.validation.passwordMax);

export const deviceNameSchema = z.object({
  name: z
    .string({ required_error: de.validation.required })
    .min(1, de.validation.required)
    .max(80, de.validation.displayNameMax),
});

export const ingestTokenNameSchema = z.object({
  name: z
    .string({ required_error: de.validation.required })
    .min(1, de.validation.required)
    .max(80, de.validation.displayNameMax),
});

export const groupNameSchema = z.object({
  name: z
    .string({ required_error: de.validation.required })
    .min(2, de.validation.displayNameMin)
    .max(60, de.validation.displayNameMax),
});

export const joinCodeSchema = z.object({
  invite_code: z
    .string({ required_error: de.validation.required })
    .min(4, de.validation.required)
    .max(32, de.validation.required),
});

export const profileSchema = z.object({
  display_name: z
    .string({ required_error: de.validation.required })
    .min(2, de.validation.displayNameMin)
    .max(40, de.validation.displayNameMax),
});

export const timezoneSchema = z.object({
  timezone: z
    .string({ required_error: de.validation.required })
    .min(1, de.validation.timezone),
});

export const changePasswordSchema = z.object({
  current_password: z
    .string({ required_error: de.validation.required })
    .min(1, de.validation.required),
  new_password: passwordSchema,
});

export const deleteAccountSchema = z.object({
  password: z
    .string({ required_error: de.validation.required })
    .min(1, de.validation.required),
});

export const privacyDefaultsSchema = z.object({
  share_live_status: z.coerce.boolean(),
  share_usage_summary: z.coerce.boolean(),
  share_usage_detail: z.coerce.boolean(),
  share_device_stats: z.coerce.boolean(),
  show_in_leaderboard: z.coerce.boolean(),
});

export const privacyOverrideValueSchema = z.enum(["inherit", "on", "off"]);

export const memberRoleSchema = z.enum(["owner", "admin", "member"]);
