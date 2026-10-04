export type FieldErrors = Partial<Record<string, string[]>>;

export type AuthFormState = {
  message?: string;
  fieldErrors?: FieldErrors;
};
