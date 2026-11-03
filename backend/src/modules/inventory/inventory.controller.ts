import type { Request, Response } from "express";
import type { AccessTokenPayload } from "../auth/auth.types";

import {
  inventoryEntrySchema,
  inventoryAdjustmentSchema,
  inventoryStockQuerySchema,
  inventoryKardexQuerySchema,
} from "./inventory.schemas";

import {
  registerInventoryEntryService,
  registerInventoryAdjustmentService,
  getInventoryStockService,
  getInventoryKardexService,
} from "./inventory.service";

function getAuthenticatedUserId(res: Response): number {
  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  return auth.idUsuario;
}

export async function registerInventoryEntry(
  req: Request,
  res: Response,
): Promise<void> {
  const input = inventoryEntrySchema.parse(req.body);

  const result = await registerInventoryEntryService(
    input,
    getAuthenticatedUserId(res),
  );

  res.status(201).json({ data: result });
}

export async function registerInventoryAdjustment(
  req: Request,
  res: Response,
): Promise<void> {
  const input = inventoryAdjustmentSchema.parse(req.body);

  const result = await registerInventoryAdjustmentService(
    input,
    getAuthenticatedUserId(res),
  );

  res.status(201).json({ data: result });
}

export async function listInventoryStock(
  req: Request,
  res: Response,
): Promise<void> {
  const filters = inventoryStockQuerySchema.parse(req.query);

  const result = await getInventoryStockService(filters);

  res.status(200).json(result);
}

export async function listInventoryKardex(
  req: Request,
  res: Response,
): Promise<void> {
  const filters = inventoryKardexQuerySchema.parse(req.query);

  const result = await getInventoryKardexService(filters);

  res.status(200).json(result);
}
