import { useId } from "react";
import type { Ref, SelectHTMLAttributes } from "react";

export interface SelectOption {
  value: string | number;
  label: string;
  disabled?: boolean;
}

export interface SelectProps extends Omit<SelectHTMLAttributes<HTMLSelectElement>, "children" | "multiple" | "size" | "value" | "defaultValue"> {
  label: string;
  options: readonly SelectOption[];
  placeholder?: string;
  helperText?: string;
  error?: string;
  value?: string | number;
  defaultValue?: string | number;
  ref?: Ref<HTMLSelectElement>;
}

export function Select({
  label, options, placeholder, helperText, error, id, required, disabled,
  value, defaultValue, ref, className = "",
  "aria-describedby": describedBy, "aria-invalid": ariaInvalid, ...props
}: SelectProps) {
  const generatedId = useId();
  const selectId = id ?? generatedId;
  const helperId = `${selectId}-help`;
  const errorId = `${selectId}-error`;
  const description = [describedBy, helperText ? helperId : undefined, error ? errorId : undefined]
    .filter(Boolean).join(" ") || undefined;

  return (
    <div className="flex min-w-0 flex-col gap-2">
      <label htmlFor={selectId} className="text-sm font-medium text-ink">
        {label}{required && <span aria-hidden="true" className="ml-1 text-danger">*</span>}
      </label>
      <select
        {...props}
        id={selectId}
        ref={ref}
        required={required}
        disabled={disabled}
        value={value}
        defaultValue={defaultValue ?? (value === undefined ? "" : undefined)}
        aria-describedby={description}
        aria-invalid={error ? true : ariaInvalid}
        className={`h-11 w-full min-w-0 rounded-lg border bg-white px-3 pr-10 text-base text-ink transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 disabled:cursor-not-allowed disabled:bg-canvas disabled:opacity-60 motion-reduce:transition-none ${error ? "border-danger enabled:hover:border-danger focus-visible:outline-danger" : "border-line enabled:hover:border-muted focus-visible:border-brand focus-visible:outline-brand"} ${className}`}
      >
        {/* Keep an explicit empty choice, including when options arrive later. */}
        {!options.some((option) => option.value === "") && (
          <option value="">{placeholder ?? "Selecciona una opción"}</option>
        )}
        {options.map((option) => (
          <option key={option.value} value={option.value} disabled={option.disabled}>
            {option.value === "" ? placeholder ?? option.label : option.label}
          </option>
        ))}
      </select>
      {helperText && <p id={helperId} className="text-sm text-muted">{helperText}</p>}
      {error && <p id={errorId} role="alert" className="text-sm text-danger">{error}</p>}
    </div>
  );
}
