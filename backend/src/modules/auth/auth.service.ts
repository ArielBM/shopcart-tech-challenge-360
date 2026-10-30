import * as argon2 from "argon2";

import { authConfig } from "../../config/auth.config";
import {
  createSession,
  createUser,
  findUserByEmail,
  rotateSession,
} from "./auth.repository";
import type { LoginInput, RegisterInput } from "./auth.schemas";
import { createAccessToken } from "./auth.tokens";
import { isRole } from "./auth.types";
import { generateRefreshToken, hashRefreshToken } from "./auth.refresh";

// Hash ficticio con el mismo coste que el registro; evita omitir Argon2 si no existe el usuario.
const dummyPasswordHash =
  "$argon2id$v=19$m=65536,p=4,t=3$jNUCzbG228Pqx/QhHJEl8w$GSMBiImPazaKyIWZ0RjSd/62O1Kvx+3IXECewKwPtH0";

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

  const validPassword = await argon2.verify(
    user?.HashContrasena ?? dummyPasswordHash,
    data.contrasena,
  );

  if (!user || !validPassword) return null;

  if (!isRole(user.Rol)) {
    throw new Error("El usuario tiene un rol no admitido.");
  }

  const refreshToken = generateRefreshToken();
  const tokenHash = hashRefreshToken(refreshToken);

  const session = await createSession(user.IDUsuario, tokenHash);

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
    expiresIn: authConfig.accessTokenExpirationSeconds,
    refreshToken,
    refreshTokenExpiresAt: session.FechaExpiracion,
  };
}

export async function refreshSession(currentToken: string) {
  const newRefreshToken = generateRefreshToken();

  const currentTokenHash = hashRefreshToken(currentToken);
  const newTokenHash = hashRefreshToken(newRefreshToken);

  const session = await rotateSession(currentTokenHash, newTokenHash);

  if (!isRole(session.Rol))
    throw new Error("La sesión tiene un rol no admitido.");

  const accessToken = await createAccessToken({
    idUsuario: session.IDUsuario,
    rol: session.Rol,
  });

  return {
    user: {
      idUsuario: session.IDUsuario,
      correo: session.Correo,
      nombre: session.Nombre,
      rol: session.Rol,
    },
    accessToken,
    tokenType: "Bearer" as const,
    expiresIn: authConfig.accessTokenExpirationSeconds,
    refreshToken: newRefreshToken,
    refreshTokenExpiresAt: session.FechaExpiracion,
  };
}
