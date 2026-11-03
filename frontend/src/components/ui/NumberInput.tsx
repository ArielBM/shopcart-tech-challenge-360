import { InputField } from "./TextInput";
import type { TextInputProps } from "./TextInput";

export type NumberInputProps = Omit<TextInputProps, "type">;

// Preserve the browser's value and validation; an empty field stays empty.
export function NumberInput(props: NumberInputProps) {
  return <InputField {...props} type="number" />;
}
