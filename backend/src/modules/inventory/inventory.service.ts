import {
  registerInventoryEntry,
  registerInventoryAdjustment,
  getInventoryStock,
  getInventoryKardex,
} from "./inventory.repository";

import type {
  InventoryEntryData,
  InventoryAdjustmentData,
  InventoryStockQuery,
  InventoryKardexQuery,
} from "./inventory.schemas";

export async function registerInventoryEntryService(
  input: InventoryEntryData,
  idUsuario: number,
) {
  const result = await registerInventoryEntry({
    ...input,
    idUsuario,
  });

  return {
    idInventarioPorUbicacion: result.IDInventarioPorUbicacion,
    idMovimientoInventario: result.IDMovimientoInventario,
    idVariante: result.IDVariante,
    idUbicacion: result.IDUbicacion,
    tipoMovimiento: result.TipoMovimiento,
    cantidadCambio: result.CantidadCambio,
    existenciaAnterior: result.ExistenciaAnterior,
    existenciaFisica: result.ExistenciaFisica,
    cantidadReservada: result.CantidadReservada,
    disponible: result.Disponible,
  };
}

export async function registerInventoryAdjustmentService(
  input: InventoryAdjustmentData,
  idUsuario: number,
) {
  const result = await registerInventoryAdjustment({
    ...input,
    idUsuario,
  });

  return {
    idInventarioPorUbicacion: result.IDInventarioPorUbicacion,
    idMovimientoInventario: result.IDMovimientoInventario,
    cantidadCambio: result.CantidadCambio,
    existenciaFisica: result.ExistenciaFisica,
    cantidadReservada: result.CantidadReservada,
    disponible: result.Disponible,
  };
}

export async function getInventoryStockService(filters: InventoryStockQuery) {
  const records = await getInventoryStock(filters);

  return {
    data: records.map((record) => ({
      idInventarioPorUbicacion: record.IDInventarioPorUbicacion,
      idVariante: record.IDVariante,
      sku: record.SKU,
      producto: record.Producto,
      idUbicacion: record.IDUbicacion,
      codigoUbicacion: record.CodigoUbicacion,
      ubicacion: record.Ubicacion,
      existenciaFisica: record.ExistenciaFisica,
      cantidadReservada: record.CantidadReservada,
      disponible: record.Disponible,
      fechaActualizacion: record.FechaActualizacion,
    })),
  };
}

export async function getInventoryKardexService(filters: InventoryKardexQuery) {
  const result = await getInventoryKardex(filters);

  return {
    data: result.movements.map((movement) => ({
      idMovimientoInventario: movement.IDMovimientoInventario,
      idVariante: movement.IDVariante,
      idUbicacion: movement.IDUbicacion,
      codigoUbicacion: movement.CodigoUbicacion,
      tipoMovimiento: movement.TipoMovimiento,
      cantidadCambio: movement.CantidadCambio,
      motivo: movement.Motivo,
      idUsuario: movement.IDUsuario,
      idDetallePedido: movement.IDDetallePedido,
      idDetalleDevolucion: movement.IDDetalleDevolucion,
      fechaMovimiento: movement.FechaMovimiento,
    })),
    pagination: {
      pagina: filters.pagina,
      tamanoPagina: filters.tamanoPagina,
      totalRegistros: result.totalRegistros,
    },
  };
}
