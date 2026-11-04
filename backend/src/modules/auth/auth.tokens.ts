import { SignJWT, jwtVerify } from "jose";
import { authConfig } from "../../config/auth.config";
import { isRole, type AccessTokenPayload } from "./auth.types";

export async function createAccessToken(
  user: AccessTokenPayload,
): Promise<string> {
  const issuedAt = Math.floor(Date.now() / 1000);

  if (
    !Number.isSafeInteger(user.versionSeguridad) ||
    user.versionSeguridad < 1 ||
    user.versionSeguridad > 2147483647
  ) {
    throw new Error("Versión de seguridad inválida.");
  }

  return new SignJWT({
    rol: user.rol,
    versionSeguridad: user.versionSeguridad,
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setSubject(String(user.idUsuario))
    .setIssuer(authConfig.jwtIssuer)
    .setAudience(authConfig.jwtAudience)
    .setIssuedAt(issuedAt)
    .setExpirationTime(issuedAt + authConfig.accessTokenExpirationSeconds)
    .sign(authConfig.jwtSecret);
}

export async function verifyAccessToken(
  token: string,
): Promise<AccessTokenPayload> {
  const { payload } = await jwtVerify(token, authConfig.jwtSecret, {
    algorithms: ["HS256"],
    issuer: authConfig.jwtIssuer,
    audience: authConfig.jwtAudience,
    requiredClaims: ["sub", "iat", "exp", "versionSeguridad"],
  });

  const idUsuario = Number(payload.sub);
  const versionSeguridad = payload.versionSeguridad;

  if (
    !Number.isSafeInteger(idUsuario) ||
    idUsuario <= 0 ||
    !isRole(payload.rol) ||
    typeof versionSeguridad !== "number" ||
    !Number.isSafeInteger(versionSeguridad) ||
    versionSeguridad < 1 ||
    versionSeguridad > 2147483647
  ) {
    throw new Error("Access token con claims inválidos.");
  }

  return {
    idUsuario,
    rol: payload.rol,
    versionSeguridad,
  };
}
