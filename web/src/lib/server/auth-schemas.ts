import { z } from "zod";
import { de } from "#lib/i18n/de.js";

const passwordSchema = z
  .string({ required_error: de.validation.required })
  .min(12, de.validation.passwordMin)
  .max(128, de.validation.passwordMax);

export const loginSchema = z.object({
  email: z
    .string({ required_error: de.validation.required })
    .email(de.validation.email),
  password: passwordSchema,
});

export const registerSchema = z.object({
  email: z
    .string({ required_error: de.validation.required })
    .email(de.validation.email),
  password: passwordSchema,
  display_name: z
    .string({ required_error: de.validation.required })
    .min(2, de.validation.displayNameMin)
    .max(40, de.validation.displayNameMax),
  timezone: z
    .string({ required_error: de.validation.required })
    .min(1, de.validation.timezone),
});

export type LoginInput = z.infer<typeof loginSchema>;
export type RegisterInput = z.infer<typeof registerSchema>;
