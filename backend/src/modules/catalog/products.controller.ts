import type { Request, Response } from "express";
import type { AccessTokenPayload } from "../auth/auth.types";

import {
  productIdSchema,
  createProductSchema,
  updateProductSchema,
  listProductsSchema,
} from "./products.schemas";

import {
  createProductService,
  updateProductService,
  listProductsService,
} from "./products.service";

function getAuthenticatedUser(res: Response): AccessTokenPayload {
  const auth = res.locals.auth as AccessTokenPayload | undefined;

  if (!auth) {
    throw new Error("Usuario autenticado no disponible.");
  }

  return auth;
}

export async function createProduct(
  req: Request,
  res: Response,
): Promise<void> {
  const input = createProductSchema.parse(req.body);
  const { idUsuario } = getAuthenticatedUser(res);

  const product = await createProductService(input, idUsuario);

  res.status(201).json({ data: product });
}

export async function updateProduct(
  req: Request,
  res: Response,
): Promise<void> {
  const idProducto = productIdSchema.parse(req.params.idProducto);

  const input = updateProductSchema.parse(req.body);
  const { idUsuario } = getAuthenticatedUser(res);

  const product = await updateProductService(idProducto, input, idUsuario);

  res.status(200).json({ data: product });
}

export async function listProducts(req: Request, res: Response): Promise<void> {
  const filters = listProductsSchema.parse(req.query);

  // La ruta determina si pueden verse productos inactivos.
  const soloActivos = res.locals.adminCatalog !== true;

  const result = await listProductsService(filters, soloActivos);

  res.status(200).json(result);
}
