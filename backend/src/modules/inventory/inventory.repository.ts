import sql from "mssql";
import { getConnection } from "../../database/connection";

import type {
  InventoryEntryInput,
  InventoryAdjustmentInput,
  InventoryEntryRecord,
  InventoryAdjustmentRecord,
  InventoryStockRecord,
  InventoryKardexRecord,
} from "./inventory.types";

import type {
  InventoryStockQuery,
  InventoryKardexQuery,
} from "./inventory.schemas";

export async function registerInventoryEntry(
  data: InventoryEntryInput,
): Promise<InventoryEntryRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDVariante", sql.Int, data.idVariante)
    .input("IDUbicacion", sql.Int, data.idUbicacion)
    .input("Cantidad", sql.Int, data.cantidad)
    .input("Motivo", sql.NVarChar(300), data.motivo)
    .input("IDUsuario", sql.Int, data.idUsuario)
    .execute<InventoryEntryRecord>("dbo.SP_Inventario_RegistrarEntrada");

  const inventory = result.recordset[0];

  if (!inventory) {
    throw new Error("El registro de entrada no devolvió un resultado.");
  }

  return inventory;
}

export async function registerInventoryAdjustment(
  data: InventoryAdjustmentInput,
): Promise<InventoryAdjustmentRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDVariante", sql.Int, data.idVariante)
    .input("IDUbicacion", sql.Int, data.idUbicacion)
    .input("CantidadCambio", sql.Int, data.cantidadCambio)
    .input("Motivo", sql.NVarChar(300), data.motivo)
    .input("IDUsuario", sql.Int, data.idUsuario)
    .execute<InventoryAdjustmentRecord>("dbo.SP_Inventario_RegistrarAjuste");

  const inventory = result.recordset[0];

  if (!inventory) {
    throw new Error("El ajuste de inventario no devolvió un resultado.");
  }

  return inventory;
}

export async function getInventoryStock(
  filters: InventoryStockQuery,
): Promise<InventoryStockRecord[]> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDVariante", sql.Int, filters.idVariante ?? null)
    .input("IDUbicacion", sql.Int, filters.idUbicacion ?? null)
    .execute<InventoryStockRecord>("dbo.SP_Inventario_ConsultarExistencias");

  return result.recordset;
}

export async function getInventoryKardex(
  filters: InventoryKardexQuery,
): Promise<{
  movements: InventoryKardexRecord[];
  totalRegistros: string;
}> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDVariante", sql.Int, filters.idVariante)
    .input("IDUbicacion", sql.Int, filters.idUbicacion ?? null)
    .input("FechaDesde", sql.DateTime2(3), filters.fechaDesde ?? null)
    .input("FechaHasta", sql.DateTime2(3), filters.fechaHasta ?? null)
    .input("Pagina", sql.Int, filters.pagina)
    .input("TamanoPagina", sql.Int, filters.tamanoPagina)
    .output("TotalRegistros", sql.BigInt)
    .execute<InventoryKardexRecord>("dbo.SP_Inventario_ConsultarKardex");

  return {
    movements: result.recordset,
    totalRegistros: String(result.output.TotalRegistros),
  };
}
