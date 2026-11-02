import sql from "mssql";

import { getConnection } from "../../database/connection";

import type {
  ProductData,
  ProductRecord,
  ProductListRecord,
  UpdateProductData,
} from "./catalog.types";

import type { ListProductInput } from "./products.schemas";

export async function createProduct(data: ProductData): Promise<ProductRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDCategoria", sql.Int, data.idCategoria)
    .input("Nombre", sql.NVarChar(200), data.nombre)
    .input("Descripcion", sql.NVarChar(sql.MAX), data.descripcion)
    .input("IDUsuario", sql.Int, data.idUsuario)
    .execute<ProductRecord>("dbo.SP_Catalogo_CrearProducto");

  const product = result.recordset[0];

  if (!product) throw new Error("La creación no devolvió un producto.");

  return product;
}

export async function updateProduct(
  data: UpdateProductData,
): Promise<ProductRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDProducto", sql.Int, data.idProducto)
    .input("IDCategoria", sql.Int, data.idCategoria)
    .input("Nombre", sql.NVarChar(200), data.nombre)
    .input("Descripcion", sql.NVarChar(sql.MAX), data.descripcion)
    .input("Activo", sql.Bit, data.activo)
    .input("IDUsuario", sql.Int, data.idUsuario)
    .execute<ProductRecord>("dbo.SP_Catalogo_ActualizarProducto");

  const product = result.recordset[0];

  if (!product) throw new Error("La actualización no devolvió un producto.");

  return product;
}

export async function listProducts(
  filters: ListProductInput,
  soloActivos: boolean,
): Promise<{
  products: ProductListRecord[];
  totalRegistros: number;
}> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("Busqueda", sql.NVarChar(200), filters.busqueda ?? null)
    .input("IDCategoria", sql.Int, filters.idCategoria ?? null)
    .input("PrecioMinimo", sql.VarChar(20), filters.precioMinimo ?? null)
    .input("PrecioMaximo", sql.VarChar(20), filters.precioMaximo ?? null)
    .input("SoloDisponibles", sql.Bit, filters.soloDisponibles)
    .input("SoloActivos", sql.Bit, soloActivos)
    .input("Pagina", sql.Int, filters.pagina)
    .input("TamanoPagina", sql.Int, filters.tamanoPagina)
    .input("Orden", sql.VarChar(20), filters.orden)
    .output("TotalRegistros", sql.Int)
    .execute<ProductListRecord>("dbo.SP_Catalogo_ListarProductos");

  return {
    products: result.recordset,
    totalRegistros: result.output.TotalRegistros as number,
  };
}
