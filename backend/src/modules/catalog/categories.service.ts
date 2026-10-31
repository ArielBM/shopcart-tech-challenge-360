import {
  createCategory,
  listCategories,
  updateCategory,
} from "./categories.repository";

import { CategoryRecord } from "./catalog.types";

import { CreateCategoryInput, UpdateCategoryInput } from "./categories.schemas";

function toCategoryResponse(category: CategoryRecord) {
  return {
    idCategoria: category.IDCategoria,
    nombre: category.Nombre,
    descripcion: category.Descripcion,
    activa: category.Activa,
    fechaCreacion: category.FechaCreacion,
  };
}

export async function createCategoryService(data: CreateCategoryInput) {
  const category = await createCategory(data);
  return toCategoryResponse(category);
}

export async function listCategoriesService(soloActivas: boolean) {
  const categories = await listCategories(soloActivas);
  return categories.map(toCategoryResponse);
}

export async function updateCategoryService(
  idCategoria: number,
  data: UpdateCategoryInput,
) {
  const category = await updateCategory({
    idCategoria,
    ...data,
  });

  return toCategoryResponse(category);
}
