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
  VersionSeguridad: number;
}

export interface AccessTokenPayload {
  idUsuario: number;
  rol: Role;
  versionSeguridad: number;
}

export interface CreatedSession {
  IDRefreshToken: number;
  IDFamilia: string;
  FechaExpiracion: Date;
  VersionSeguridad: number;
}

export interface RotatedSession {
  IDUsuario: number;
  Correo: string;
  Nombre: string;
  Rol: string;
  FechaExpiracion: Date;
  VersionSeguridad: number;
}

export interface ActiveUserRecord {
  IDUsuario: number;
  Activo: boolean;
  Rol: string;
  VersionSeguridad: number;
}

export type Role = "CLIENTE" | "OPERADOR" | "ADMINISTRADOR";

export function isRole(value: unknown): value is Role {
  return (
    value === "CLIENTE" || value === "OPERADOR" || value === "ADMINISTRADOR"
  );
}
