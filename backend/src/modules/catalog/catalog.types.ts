export interface CategoryRecord {
  IDCategoria: number;
  Nombre: string;
  Descripcion: string | null;
  Activa: boolean;
  FechaCreacion: Date;
}

export interface CategoryData {
  nombre: string;
  descripcion: string | null;
}

export interface UpdateCategoryData extends CategoryData {
  idCategoria: number;
  activa: boolean;
}

export interface ProductRecord {
  IDProducto: number;
  IDCategoria: number;
  Nombre: string;
  Descripcion: string | null;
  Activo: boolean;
  FechaCreacion: Date;
  FechaActualizacion: Date;
}

export interface ProductListRecord extends ProductRecord {
  Categoria: string;
  PrecioDesde: number | null;
  CantidadVariantes: number;
  DisponibleTotal: number;
  TotalRegistros: number;
}

export interface ProductData {
  idCategoria: number;
  nombre: string;
  descripcion: string | null;
  idUsuario: number;
}

export interface UpdateProductData extends ProductData {
  idProducto: number;
  activo: boolean;
}
