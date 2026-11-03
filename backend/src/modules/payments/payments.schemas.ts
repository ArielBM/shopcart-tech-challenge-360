import { z } from "zod";

const positiveBigIntSchema = z
  .string()
  .regex(/^[1-9]\d{0,18}$/, "Identificador inválido.")
  .refine(
    (value) => BigInt(value) <= 9223372036854775807n,
    "El identificador supera el límite de BIGINT.",
  );

export const paymentParamsSchema = z.strictObject({
  idCheckout: positiveBigIntSchema,
});

export const processPaymentSchema = z.strictObject({
  idDireccion: positiveBigIntSchema,
  claveIdempotencia: z.uuid(),
});

export type PaymentParams = z.infer<typeof paymentParamsSchema>;
export type ProcessPaymentData = z.infer<typeof processPaymentSchema>;
