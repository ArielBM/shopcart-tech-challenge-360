export type UserRole = "CLIENTE" | "OPERADOR" | "ADMINISTRADOR";

export interface AuthUser {
  idUsuario: number;
  nombre: string;
  correo: string;
  rol: UserRole;
}

export interface AuthSession {
  user: AuthUser;
  accessToken: string;
  tokenType: "Bearer";
  expiresIn: number;
}

export interface AuthResponse {
  data: AuthSession;
}

export interface RegisterInput {
  nombre: string;
  correo: string;
  contrasena: string;
}

export interface RegisteredUser {
  idUsuario: number;
  nombre: string;
  correo: string;
}

export interface RegisterResponse {
  data: RegisteredUser;
}

export interface LoginInput {
  correo: string;
  contrasena: string;
}

export type AuthStatus =
  | "idle"
  | "loading"
  | "authenticated"
  | "unauthenticated";
