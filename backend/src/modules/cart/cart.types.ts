export interface CartLineRecord {
  IDDetalleCarrito: string | number;
  IDVariante: number;
  SKU: string;
  Producto: string;
  Cantidad: number;
  PrecioUnitario: string;
  Subtotal: string;
}

export interface CartSummaryRecord {
  IDCarrito: string | number | null;
  CantidadArticulos: number | string;
  Subtotal: string;
  Descuento: string;
  Total: string;
}

export interface CartItemRecord {
  IDCarrito: string | number;
  IDDetalleCarrito: string | number;
  IDVariante: number;
  Cantidad: number;
}

export interface CartDeletedItemRecord {
  IDCarrito: string | number;
  IDVariante: number;
  Eliminado: boolean;
}
