import z from "zod";

const sqlIntId = z.number().int().positive().max(2147483647);

const movementBaseSchema = z.strictObject({
  idVariante: sqlIntId,
  idUbicacion: sqlIntId,
  motivo: z.string().trim().min(1).max(300),
});

export const inventoryEntrySchema = movementBaseSchema.extend({
  cantidad: z.number().int().positive().max(2147483647),
});

export const inventoryAdjustmentSchema = movementBaseSchema.extend({
  cantidadCambio: z
    .number()
    .int()
    .min(-2147483648)
    .max(2147483647)
    .refine((value) => value !== 0, {
      message: "El ajuste debe ser distinto de cero.",
    }),
});

const queryIdSchema = z.coerce
  .number<number>()
  .int()
  .positive()
  .max(2147483647);

export const inventoryStockQuerySchema = z.strictObject({
  idVariante: queryIdSchema.optional(),
  idUbicacion: queryIdSchema.optional(),
});

const queryDateSchema = z.iso
  .datetime({ offset: true })
  .transform((value) => new Date(value));

export const inventoryKardexQuerySchema = z
  .strictObject({
    idVariante: queryIdSchema,
    idUbicacion: queryIdSchema.optional(),
    fechaDesde: queryDateSchema.optional(),
    fechaHasta: queryDateSchema.optional(),
    pagina: z.coerce.number<number>().int().min(1).max(2147483647).default(1),
    tamanoPagina: z.coerce.number<number>().int().min(1).max(100).default(20),
  })
  .refine(
    (data) =>
      !data.fechaDesde ||
      !data.fechaHasta ||
      data.fechaDesde <= data.fechaHasta,
    { message: "El rango de fechas no es válido." },
  );

export type InventoryEntryData = z.infer<typeof inventoryEntrySchema>;
export type InventoryAdjustmentData = z.infer<typeof inventoryAdjustmentSchema>;
export type InventoryStockQuery = z.infer<typeof inventoryStockQuerySchema>;
export type InventoryKardexQuery = z.infer<typeof inventoryKardexQuerySchema>;
