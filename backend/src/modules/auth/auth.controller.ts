import type { Request, Response } from "express";
import { loginSchema, registerSchema } from "./auth.schemas";
import { registerClient, validateCredentials } from "./auth.service";

export async function register(req: Request, res: Response): Promise<void> {
  const input = registerSchema.parse(req.body);
  const user = await registerClient(input);

  res.status(201).json({
    data: user,
  });
}

export async function login(req: Request, res: Response): Promise<void> {
  const input = loginSchema.parse(req.body);
  const result = await validateCredentials(input);

  if (!result) {
    res.status(401).json({
      error: {
        code: "INVALID_CREDENTIALS",
        message: "Correo o contraseña incorrectos.",
      },
    });
    return;
  }

  res.status(200).json({
    data: result,
  });
}
