import sql from "mssql";
import { getConnection } from "../../database/connection";
import {
  CategoryData,
  CategoryRecord,
  UpdateCategoryData,
} from "./categories.types";

export async function createCategory(
  data: CategoryData,
): Promise<CategoryRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("Nombre", sql.NVarChar(120), data.nombre)
    .input("Descripcion", sql.NVarChar(500), data.descripcion)
    .execute<CategoryRecord>("dbo.SP_Catalogo_CrearCategoria");

  const category = result.recordset[0];

  if (!category) throw new Error("La creación no devolvió una categoría.");

  return category;
}

export async function listCategories(
  soloActivas: boolean,
): Promise<CategoryRecord[]> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("SoloActivas", sql.Bit, soloActivas)
    .execute<CategoryRecord>("dbo.SP_Catalogo_ListarCategorias");

  return result.recordset;
}

export async function updateCategory(
  data: UpdateCategoryData,
): Promise<CategoryRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDCategoria", sql.Int, data.idCategoria)
    .input("Nombre", sql.NVarChar(120), data.nombre)
    .input("Descripcion", sql.NVarChar(500), data.descripcion)
    .input("Activa", sql.Bit, data.activa)
    .execute<CategoryRecord>("dbo.SP_Catalogo_ActualizarCategoria");

  const category = result.recordset[0];

  if (!category) throw new Error("La actualización no devolvió una categoría.");

  return category;
}
