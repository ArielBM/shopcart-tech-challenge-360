import z from "zod";

export const registerSchema = z.strictObject({
  nombre: z.string().trim().min(1).max(150),
  correo: z
    .email()
    .max(254)
    .transform((value) => value.toLowerCase()),
  contrasena: z.string().min(8).max(128),
});

export type RegisterInput = z.infer<typeof registerSchema>;
