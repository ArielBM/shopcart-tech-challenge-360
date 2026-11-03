import type { Request, Response } from "express";
import type { AccessTokenPayload } from "../auth/auth.types";

import { createAddressSchema } from "./addresses.schemas";
import { createAddressService, getAddressesService } from "./addresses.service";

export async function createAddressController(
  req: Request,
  res: Response,
): Promise<void> {
  const input = createAddressSchema.parse(req.body);

  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  const result = await createAddressService(auth.idUsuario, input);

  res.status(201).json(result);
}

export async function getAddressesController(
  _req: Request,
  res: Response,
): Promise<void> {
  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  const result = await getAddressesService(auth.idUsuario);

  res.status(200).json(result);
}
