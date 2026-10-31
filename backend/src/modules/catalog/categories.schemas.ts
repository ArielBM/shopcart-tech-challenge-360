import z from "zod";

export const categoryIdSchema = z.coerce
  .number<number>()
  .int()
  .positive()
  .max(2147483647);

export const createCategorySchema = z.strictObject({
  nombre: z.string().trim().min(1).max(120),
  descripcion: z.string().max(500).nullable().default(null),
});

export const UpdateCategorySchema = createCategorySchema.extend({
  activa: z.boolean(),
});

export const listCategoriesSchema = z.strictObject({
  soloActivas: z
    .enum(["true", "false"])
    .transform((value) => value === "true")
    .default(true),
});

export type CreateCategoryInput = z.infer<typeof createCategorySchema>;
export type UpdateCategoryInput = z.infer<typeof UpdateCategorySchema>;
