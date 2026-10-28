import type { Request, Response } from "express";
import { registerSchema } from "./auth.schemas";
import { registerClient } from "./auth.service";

export async function register(req: Request, res: Response): Promise<void> {
  const input = registerSchema.parse(req.body);
  const user = await registerClient(input);

  res.status(201).json({
    data: user,
  });
}
