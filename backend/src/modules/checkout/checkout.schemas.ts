import { z } from "zod";

const checkoutIdSchema = z
  .string()
  .regex(/^[1-9]\d{0,18}$/)
  .refine(
    (value) => BigInt(value) <= 9223372036854775807n,
    "El identificador supera el límite de BIGINT.",
  );

export const startCheckoutSchema = z.strictObject({
  claveInicio: z.uuid(),
});

export const checkoutParamsSchema = z.strictObject({
  idCheckout: checkoutIdSchema,
});

export type StartCheckoutData = z.infer<typeof startCheckoutSchema>;

export type CheckoutParams = z.infer<typeof checkoutParamsSchema>;
