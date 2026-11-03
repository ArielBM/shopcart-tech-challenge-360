import type { Request, Response } from "express";
import type { AccessTokenPayload } from "../auth/auth.types";

import { startCheckoutSchema, checkoutParamsSchema } from "./checkout.schemas";

import {
  startCheckoutService,
  cancelCheckoutService,
} from "./checkout.service";

export async function startCheckoutController(
  req: Request,
  res: Response,
): Promise<void> {
  const input = startCheckoutSchema.parse(req.body);

  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  const result = await startCheckoutService(auth.idUsuario, input.claveInicio);

  res.status(result.data.reutilizado ? 200 : 201).json(result);
}

export async function cancelCheckoutController(
  req: Request,
  res: Response,
): Promise<void> {
  const { idCheckout } = checkoutParamsSchema.parse(req.params);

  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  const result = await cancelCheckoutService(auth.idUsuario, idCheckout);

  res.status(200).json(result);
}
