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
