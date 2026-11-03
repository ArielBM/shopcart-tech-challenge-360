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
