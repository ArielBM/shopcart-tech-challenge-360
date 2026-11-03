import {
  createProduct,
  updateProduct,
  listProducts,
} from "./products.repository";

import type { ProductRecord, ProductListRecord } from "./products.types";

import type {
  CreateProductInput,
  UpdateProductInput,
  ListProductInput,
} from "./products.schemas";

function toProductResponse(product: ProductRecord) {
  return {
    idProducto: product.IDProducto,
    idCategoria: product.IDCategoria,
    nombre: product.Nombre,
    descripcion: product.Descripcion,
    activo: product.Activo,
    fechaCreacion: product.FechaCreacion,
    fechaActualizacion: product.FechaActualizacion,
  };
}

function toProductListResponse(product: ProductListRecord) {
  return {
    ...toProductResponse(product),
    categoria: product.Categoria,
    precioDesde: product.PrecioDesde,
    cantidadVariantes: product.CantidadVariantes,
    disponibleTotal: product.DisponibleTotal,
  };
}

export async function createProductService(
  input: CreateProductInput,
  idUsuario: number,
) {
  const product = await createProduct({
    ...input,
    idUsuario,
  });

  return toProductResponse(product);
}

export async function updateProductService(
  idProducto: number,
  input: UpdateProductInput,
  idUsuario: number,
) {
  const product = await updateProduct({
    ...input,
    idProducto,
    idUsuario,
  });

  return toProductResponse(product);
}

export async function listProductsService(
  filters: ListProductInput,
  soloActivos: boolean,
) {
  const { products, totalRegistros } = await listProducts(filters, soloActivos);

  return {
    data: products.map(toProductListResponse),
    pagination: {
      pagina: filters.pagina,
      tamanoPagina: filters.tamanoPagina,
      totalRegistros,
    },
  };
}
