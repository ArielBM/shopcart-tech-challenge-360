import { z } from "zod";

const cartSqlInt = z.number().int().positive().max(2147483647);

export const addCartItemSchema = z.strictObject({
  idVariante: cartSqlInt,
  cantidad: cartSqlInt,
});

export const cartItemParamsSchema = z.strictObject({
  idVariante: z.coerce.number<number>().int().positive().max(2147483647),
});

export const updateCartItemSchema = z.strictObject({
  cantidad: cartSqlInt,
});

export type CartItemParams = z.infer<typeof cartItemParamsSchema>;
export type UpdateCartItemData = z.infer<typeof updateCartItemSchema>;
