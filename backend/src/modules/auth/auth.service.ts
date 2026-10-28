import * as argon2 from "argon2";

import { createUser, findUserByEmail } from "./auth.repository";
import type { LoginInput, RegisterInput } from "./auth.schemas";
import { createAccessToken } from "./auth.tokens";

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

export async function validateCredentials(data: LoginInput) {
  const user = await findUserByEmail(data.correo);

  if (!user) return null;

  const validPassword = await argon2.verify(
    user.HashContrasena,
    data.contrasena,
  );

  if (!validPassword) return null;

  const accessToken = await createAccessToken({
    idUsuario: user.IDUsuario,
    rol: user.Rol,
  });

  return {
    user: {
      idUsuario: user.IDUsuario,
      correo: user.Correo,
      nombre: user.Nombre,
      rol: user.Rol,
    },
    accessToken,
    tokenType: "Bearer" as const,
    expiresIn: 900,
  };
}
