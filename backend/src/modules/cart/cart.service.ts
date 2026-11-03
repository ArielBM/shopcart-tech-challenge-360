import {
  getCart,
  addCartItem,
  updateCartItem,
  deleteCartItem,
} from "./cart.repository";

export async function getCartService(idUsuario: number) {
  const { lines, summary } = await getCart(idUsuario);

  return {
    data: {
      idCarrito: summary.IDCarrito === null ? null : String(summary.IDCarrito),
      items: lines.map((line) => ({
        idDetalleCarrito: String(line.IDDetalleCarrito),
        idVariante: line.IDVariante,
        sku: line.SKU,
        producto: line.Producto,
        cantidad: line.Cantidad,
        precioUnitario: line.PrecioUnitario,
        subtotal: line.Subtotal,
      })),
      cantidadArticulos: String(summary.CantidadArticulos),
      subtotal: summary.Subtotal,
      descuento: summary.Descuento,
      total: summary.Total,
    },
  };
}

export async function addCartItemService(
  idUsuario: number,
  idVariante: number,
  cantidad: number,
) {
  const item = await addCartItem(idUsuario, idVariante, cantidad);

  return {
    data: {
      idCarrito: String(item.IDCarrito),
      idDetalleCarrito: String(item.IDDetalleCarrito),
      idVariante: item.IDVariante,
      cantidad: item.Cantidad,
    },
  };
}

export async function updateCartItemService(
  idUsuario: number,
  idVariante: number,
  cantidad: number,
) {
  const item = await updateCartItem(idUsuario, idVariante, cantidad);

  return {
    data: {
      idCarrito: String(item.IDCarrito),
      idDetalleCarrito: String(item.IDDetalleCarrito),
      idVariante: item.IDVariante,
      cantidad: item.Cantidad,
    },
  };
}

export async function deleteCartItemService(
  idUsuario: number,
  idVariante: number,
) {
  const item = await deleteCartItem(idUsuario, idVariante);

  return {
    data: {
      idCarrito: String(item.IDCarrito),
      idVariante: item.IDVariante,
      eliminado: item.Eliminado,
    },
  };
}
