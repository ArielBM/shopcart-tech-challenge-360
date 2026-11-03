import { z } from "zod";

const requiredText = (maxLength: number) =>
  z.string().trim().min(1).max(maxLength);

const optionalText = (maxLength: number) =>
  z
    .string()
    .trim()
    .max(maxLength)
    .nullish()
    .transform((value) => (value === "" ? null : (value ?? null)));

export const createAddressSchema = z.strictObject({
  nombreDestinatario: requiredText(150),
  telefono: optionalText(30),
  departamento: requiredText(100),
  municipio: requiredText(100),
  direccionTexto: requiredText(500),
  referencia: optionalText(300),
});

export type CreateAddressData = z.infer<typeof createAddressSchema>;
