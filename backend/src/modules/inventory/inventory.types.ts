export interface InventoryMovementInput {
  idVariante: number;
  idUbicacion: number;
  motivo: string;
  idUsuario: number;
}

export interface InventoryEntryInput extends InventoryMovementInput {
  cantidad: number;
}

export interface InventoryAdjustmentInput extends InventoryMovementInput {
  cantidadCambio: number;
}

export interface InventoryEntryRecord {
  IDInventarioPorUbicacion: number;
  IDMovimientoInventario: string;
  IDVariante: number;
  IDUbicacion: number;
  TipoMovimiento: string;
  CantidadCambio: number;
  ExistenciaAnterior: number;
  ExistenciaFisica: number;
  CantidadReservada: number;
  Disponible: number;
}

export interface InventoryAdjustmentRecord {
  IDInventarioPorUbicacion: number;
  IDMovimientoInventario: string;
  CantidadCambio: number;
  ExistenciaFisica: number;
  CantidadReservada: number;
  Disponible: number;
}

export interface InventoryStockRecord {
  IDInventarioPorUbicacion: number;
  IDVariante: number;
  SKU: string;
  Producto: string;
  IDUbicacion: number;
  CodigoUbicacion: string;
  Ubicacion: string;
  ExistenciaFisica: number;
  CantidadReservada: number;
  Disponible: number;
  FechaActualizacion: Date;
}

export interface InventoryKardexRecord {
  IDMovimientoInventario: string;
  IDVariante: number;
  IDUbicacion: number;
  CodigoUbicacion: string;
  TipoMovimiento: string;
  CantidadCambio: number;
  Motivo: string;
  IDUsuario: number;
  IDDetallePedido: string | null;
  IDDetalleDevolucion: string | null;
  FechaMovimiento: Date;
}
