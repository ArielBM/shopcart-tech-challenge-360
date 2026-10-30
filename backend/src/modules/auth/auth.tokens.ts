import { SignJWT, jwtVerify } from "jose";
import { authConfig } from "../../config/auth.config";
import { isRole, type AccessTokenPayload } from "./auth.types";

export async function createAccessToken(
  user: AccessTokenPayload,
): Promise<string> {
  const issuedAt = Math.floor(Date.now() / 1000);

  return new SignJWT({ rol: user.rol })
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
    requiredClaims: ["sub", "iat", "exp"],
  });

  const idUsuario = Number(payload.sub);

  if (
    !Number.isSafeInteger(idUsuario) ||
    idUsuario <= 0 ||
    !isRole(payload.rol)
  ) {
    throw new Error("Access token con claims inválidos.");
  }

  return {
    idUsuario,
    rol: payload.rol,
  };
}
