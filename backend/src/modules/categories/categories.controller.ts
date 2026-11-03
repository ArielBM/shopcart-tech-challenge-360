import type { Request, Response } from "express";

import {
  createCategorySchema,
  UpdateCategorySchema,
  listCategoriesSchema,
  categoryIdSchema,
} from "./categories.schemas";

import {
  createCategoryService,
  listCategoriesService,
  updateCategoryService,
} from "./categories.service";

export async function createCategory(
  req: Request,
  res: Response,
): Promise<void> {
  const input = createCategorySchema.parse(req.body);
  const category = await createCategoryService(input);

  res.status(201).json({ data: category });
}

export async function listCategories(
  req: Request,
  res: Response,
): Promise<void> {
  const { soloActivas } = listCategoriesSchema.parse(
    res.locals.publicCatalog ? { soloActivas: "true" } : req.query,
  );

  const categories = await listCategoriesService(soloActivas);

  res.status(200).json({ data: categories });
}

export async function updateCategory(
  req: Request,
  res: Response,
): Promise<void> {
  const idCategoria = categoryIdSchema.parse(req.params.idCategoria);
  const input = UpdateCategorySchema.parse(req.body);

  const category = await updateCategoryService(idCategoria, input);

  res.status(200).json({ data: category });
}
