export interface UserQuery {
  buscar?: string;
  estado: "TODOS" | "ACTIVO" | "INACTIVO";
  pagina: number;
  tamanoPagina: number;
}

export interface UserRecord {
  IDUsuario: number;
  Correo: string;
  Nombre: string;
  Rol: string;
  Activo: boolean;
  FechaCreacion?: Date;
  FechaActualizacion: Date;
}

export interface UsersResult {
  records: UserRecord[];
  totalRegistros: string;
}

export interface ChangeUserStatus {
  idUsuario: number;
  activo: boolean;
  idAdministrador: number;
}
