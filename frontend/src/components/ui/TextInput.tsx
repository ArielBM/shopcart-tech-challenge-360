import { useId } from "react";
import type { InputHTMLAttributes, ReactNode, Ref } from "react";

type TextInputType = "text" | "email" | "search" | "tel" | "url";

export interface TextInputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "type"> {
  label: string;
  type?: TextInputType;
  error?: string;
  helperText?: string;
  ref?: Ref<HTMLInputElement>;
}

interface InputFieldProps extends Omit<TextInputProps, "type"> {
  type?: TextInputType | "password" | "number";
  leading?: ReactNode;
  trailing?: ReactNode;
}

// Shared field for TextInput and PasswordInput: one label, input and message contract.
export function InputField({
  label,
  type = "text",
  error,
  helperText,
  id,
  required,
  disabled,
  readOnly,
  className = "",
  leading,
  trailing,
  ref,
  "aria-describedby": describedBy,
  "aria-invalid": ariaInvalid,
  ...props
}: InputFieldProps) {
  const generatedId = useId();
  const inputId = id ?? generatedId;
  const helperId = `${inputId}-help`;
  const errorId = `${inputId}-error`;
  const description = [describedBy, helperText ? helperId : undefined, error ? errorId : undefined]
    .filter(Boolean).join(" ") || undefined;

  return (
    <div className="flex min-w-0 flex-col gap-2">
      <label htmlFor={inputId} className="text-sm font-medium text-ink">
        {label}{required && <span aria-hidden="true" className="ml-1 text-danger">*</span>}
      </label>
      <div className="relative min-w-0">
        {leading}
        <input
          {...props}
          ref={ref}
          id={inputId}
          type={type}
          required={required}
          disabled={disabled}
          readOnly={readOnly}
          aria-describedby={description}
          aria-invalid={error ? true : ariaInvalid}
          className={`h-11 w-full min-w-0 rounded-lg border bg-white px-3 text-base text-ink placeholder:text-muted transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 read-only:bg-canvas disabled:cursor-not-allowed disabled:bg-canvas disabled:opacity-60 motion-reduce:transition-none ${error ? "border-danger enabled:hover:border-danger focus-visible:outline-danger" : "border-line enabled:hover:border-muted focus-visible:border-brand focus-visible:outline-brand"} ${leading ? "pl-10" : ""} ${trailing ? "pr-14" : ""} ${className}`}
        />
        {trailing}
      </div>
      {helperText && <p id={helperId} className="text-sm text-muted">{helperText}</p>}
      {error && <p id={errorId} role="alert" className="text-sm text-danger">{error}</p>}
    </div>
  );
}

export function TextInput(props: TextInputProps) {
  return <InputField {...props} />;
}
