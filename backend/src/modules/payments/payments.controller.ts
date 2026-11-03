import type { Request, Response } from "express";
import type { AccessTokenPayload } from "../auth/auth.types";

import { paymentParamsSchema, processPaymentSchema } from "./payments.schemas";

import { processPaymentService } from "./payments.service";

export async function processPaymentController(
  req: Request,
  res: Response,
): Promise<void> {
  const { idCheckout } = paymentParamsSchema.parse(req.params);
  const input = processPaymentSchema.parse(req.body);

  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  const result = await processPaymentService(auth.idUsuario, idCheckout, input);

  res.status(result.data.reutilizado ? 200 : 201).json(result);
}
