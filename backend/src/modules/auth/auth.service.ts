import * as argon2 from "argon2";

import { createUser } from "./auth.repository";
import type { RegisterInput } from "./auth.schemas";

export async function registerClient(data: RegisterInput) {
  const hashContrasena = await argon2.hash(data.contrasena, {
    type: argon2.argon2id,
  });

  const user = await createUser({
    nombre: data.nombre,
    correo: data.correo,
    hashContrasena,
  });

  return {
    idUsuario: user.IDUsuario,
    correo: user.Correo,
    nombre: user.Nombre,
  };
}
