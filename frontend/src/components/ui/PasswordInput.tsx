import { useState } from "react";
import { InputField } from "./TextInput";
import type { TextInputProps } from "./TextInput";

export type PasswordInputProps = Omit<TextInputProps, "type">;

export function PasswordInput({ disabled, readOnly, autoComplete = "current-password", ...props }: PasswordInputProps) {
  const [visible, setVisible] = useState(false);

  return (
    <InputField
      {...props}
      disabled={disabled}
      readOnly={readOnly}
      autoComplete={autoComplete}
      type={visible ? "text" : "password"}
      trailing={
        <button
          type="button"
          aria-label={visible ? "Ocultar contraseña" : "Mostrar contraseña"}
          disabled={disabled}
          onClick={() => setVisible((previous) => !previous)}
          className="absolute inset-y-0 right-0 flex w-11 items-center justify-center rounded-r-lg text-muted transition-colors enabled:hover:bg-brand-soft enabled:hover:text-brand enabled:active:bg-brand/15 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:opacity-60 motion-reduce:transition-none"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />
            <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.7" />
            {visible && <path d="m3 3 18 18" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />}
          </svg>
        </button>
      }
    />
  );
}
