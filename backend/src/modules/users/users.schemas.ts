import z from "zod";

export const userIdSchema = z.coerce
  .number<number>()
  .int()
  .positive()
  .max(2147483647);

export const usersQuerySchema = z.strictObject({
  buscar: z.string().trim().min(1).max(150).optional(),

  estado: z.enum(["TODOS", "ACTIVO", "INACTIVO"]).default("TODOS"),

  pagina: z.coerce.number<number>().int().min(1).max(2147483647).default(1),

  tamanoPagina: z.coerce.number<number>().int().min(1).max(100).default(20),
});

export const changeUserStatusSchema = z.strictObject({
  activo: z.boolean(),
});
