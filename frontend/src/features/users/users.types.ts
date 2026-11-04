export type UserStatusFilter = "TODOS" | "ACTIVO" | "INACTIVO";

export interface AdminUser {
  idUsuario: number;
  correo: string;
  nombre: string;
  rol: string;
  activo: boolean;
  fechaCreacion?: string;
  fechaActualizacion: string;
}

export interface UsersQuery {
  buscar?: string;
  estado: UserStatusFilter;
  pagina: number;
  tamanoPagina: number;
}

export interface UsersResponse {
  data: AdminUser[];
  pagination: {
    pagina: number;
    tamanoPagina: number;
    totalRegistros: string;
  };
}
