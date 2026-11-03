import sql from "mssql";
import { getConnection } from "../../database/connection";

import {
  CartDeletedItemRecord,
  CartItemRecord,
  CartLineRecord,
  CartSummaryRecord,
} from "./cart.types";

export async function getCart(idUsuario: number) {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDUsuario", sql.Int, idUsuario)
    .execute<CartLineRecord>("dbo.SP_Carrito_Consultar");

  const lines = result.recordsets[0] as CartLineRecord[];
  const summaryRecords: unknown = result.recordsets[1];

  const summary = (summaryRecords as CartSummaryRecord[] | undefined)?.[0];

  if (!summary) {
    throw new Error("La consulta del carrito no devolvió un resumen.");
  }

  return { lines, summary };
}

export async function addCartItem(
  idUsuario: number,
  idVariante: number,
  cantidad: number,
): Promise<CartItemRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDVariante", sql.Int, idVariante)
    .input("Cantidad", sql.Int, cantidad)
    .input("IDUsuario", sql.Int, idUsuario)
    .execute<CartItemRecord>("dbo.SP_Carrito_AgregarProducto");

  const item = result.recordset[0];

  if (!item) {
    throw new Error("La operación no devolvió el producto agregado.");
  }

  return item;
}

export async function updateCartItem(
  idUsuario: number,
  idVariante: number,
  cantidad: number,
): Promise<CartItemRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDVariante", sql.Int, idVariante)
    .input("Cantidad", sql.Int, cantidad)
    .input("IDUsuario", sql.Int, idUsuario)
    .execute<CartItemRecord>("dbo.SP_Carrito_ActualizarCantidad");

  const item = result.recordset[0];

  if (!item) {
    throw new Error("La actualización del carrito no devolvió un resultado.");
  }

  return item;
}

export async function deleteCartItem(
  idUsuario: number,
  idVariante: number,
): Promise<CartDeletedItemRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDVariante", sql.Int, idVariante)
    .input("IDUsuario", sql.Int, idUsuario)
    .execute<CartDeletedItemRecord>("dbo.SP_Carrito_EliminarProducto");

  const item = result.recordset[0];

  if (!item) {
    throw new Error("La eliminación del producto no devolvió un resultado.");
  }

  return item;
}
