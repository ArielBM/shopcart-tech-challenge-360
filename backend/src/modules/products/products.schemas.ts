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

const priceSchema = z
  .string()
  .regex(
    /^(?:0|[1-9]\d{0,15})(?:\.\d{1,2})?$/,
    "El precio debe ser positivo y tener máximo dos decimales.",
  );

function toCents(value: string): bigint {
  const [integer = "0", fraction = ""] = value.split(".");

  return BigInt(integer) * 100n + BigInt(fraction.padEnd(2, "0"));
}

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
      toCents(data.precioMinimo) <= toCents(data.precioMaximo),
    { message: "El rango de precios no es válido." },
  );

export type CreateProductInput = z.infer<typeof createProductSchema>;
export type UpdateProductInput = z.infer<typeof updateProductSchema>;
export type ListProductInput = z.infer<typeof listProductsSchema>;
