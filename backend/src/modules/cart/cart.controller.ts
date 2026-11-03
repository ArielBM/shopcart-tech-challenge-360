import type { Request, Response } from "express";
import type { AccessTokenPayload } from "../auth/auth.types";

import {
  getCartService,
  addCartItemService,
  updateCartItemService,
  deleteCartItemService,
} from "./cart.service";
import {
  addCartItemSchema,
  cartItemParamsSchema,
  updateCartItemSchema,
} from "./cart.schemas";

export async function getCartController(
  _req: Request,
  res: Response,
): Promise<void> {
  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  const result = await getCartService(auth.idUsuario);

  res.status(200).json(result);
}

export async function addCartItemController(
  req: Request,
  res: Response,
): Promise<void> {
  const input = addCartItemSchema.parse(req.body);

  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  const result = await addCartItemService(
    auth.idUsuario,
    input.idVariante,
    input.cantidad,
  );

  res.status(201).json(result);
}

export async function updateCartItemController(
  req: Request,
  res: Response,
): Promise<void> {
  const { idVariante } = cartItemParamsSchema.parse(req.params);
  const { cantidad } = updateCartItemSchema.parse(req.body);

  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  const result = await updateCartItemService(
    auth.idUsuario,
    idVariante,
    cantidad,
  );

  res.status(200).json(result);
}

export async function deleteCartItemController(
  req: Request,
  res: Response,
): Promise<void> {
  const { idVariante } = cartItemParamsSchema.parse(req.params);

  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  await deleteCartItemService(auth.idUsuario, idVariante);

  res.status(204).send();
}
