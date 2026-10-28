export interface RegisteredUser {
  IDUsuario: number;
  Correo: string;
  Nombre: string;
}

export interface CreateUserData {
  nombre: string;
  correo: string;
  hashContrasena: string;
}

export interface LoginUser {
  IDUsuario: number;
  Correo: string;
  Nombre: string;
  HashContrasena: string;
  Rol: string;
}

export interface AccessTokenPayload {
  idUsuario: number;
  rol: string;
}

export type Role = "CLIENTE" | "OPERADOR" | "ADMINISTRADOR";
