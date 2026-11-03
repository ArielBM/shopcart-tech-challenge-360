import { InputField } from "./TextInput";
import type { TextInputProps } from "./TextInput";

export interface MoneyInputProps extends Omit<TextInputProps, "type" | "inputMode" | "value" | "defaultValue"> {
  value?: string;
  defaultValue?: string;
}

// Keep the exact string, including intermediate edits. The form validates the
// canonical decimal point, two decimal places and range before calling the API.
export function MoneyInput(props: MoneyInputProps) {
  return (
    <InputField
      {...props}
      type="text"
      inputMode="decimal"
      leading={
        <span aria-hidden="true" className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-base text-muted">
          Q
        </span>
      }
    />
  );
}
