import z from "zod";

export const productIdSchema = z.coerce
  .number<number>()
  .int()
  .positive()
  .max(2147483647);

export const createProductSchema = z.strictObject({
  idCategoria: z.number().int().positive().max(2147483647),
  nombre: z.string().trim().min(1).max(200),
  descripcion: z.string().nullable().default(null),
});

export const updateProductSchema = createProductSchema.extend({
  activo: z.boolean(),
});

const priceSchema = z.coerce
  .number<number>()
  .nonnegative()
  .max(9999999999999.99);

export const listProductsSchema = z
  .strictObject({
    busqueda: z.string().trim().max(200).optional(),
    idCategoria: productIdSchema.optional(),
    precioMinimo: priceSchema.optional(),
    precioMaximo: priceSchema.optional(),
    soloDisponibles: z
      .enum(["true", "false"])
      .transform((value) => value === "true")
      .default(false),
    orden: z
      .enum(["NOMBRE_ASC", "NOMBRE_DESC", "PRECIO_ASC", "PRECIO_DESC"])
      .default("NOMBRE_ASC"),
    pagina: z.coerce.number<number>().int().min(1).max(2147483647).default(1),
    tamanoPagina: z.coerce.number<number>().int().min(1).max(100).default(20),
  })
  .refine(
    (data) =>
      data.precioMinimo === undefined ||
      data.precioMaximo === undefined ||
      data.precioMinimo <= data.precioMaximo,
    { message: "El rango de precios no es válido." },
  );

export type CreateProductInput = z.infer<typeof createProductSchema>;
export type UpdateProductInput = z.infer<typeof updateProductSchema>;
export type ListProductInput = z.infer<typeof listProductsSchema>;
