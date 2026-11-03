import z from "zod";

export const auditQuerySchema = z.strictObject({
  modulo: z.string().trim().min(1).max(30).optional(),
  pagina: z.coerce.number<number>().int().min(1).max(2147483647).default(1),
  tamanoPagina: z.coerce.number<number>().int().min(1).max(100).default(20),
});

export type AuditQueryData = z.infer<typeof auditQuerySchema>;
