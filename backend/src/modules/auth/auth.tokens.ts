import { errors, SignJWT, jwtVerify } from "jose";
import { authConfig } from "../../config/auth.config";
import { isRole, type AccessTokenPayload } from "./auth.types";

export async function createAccessToken(
  user: AccessTokenPayload,
): Promise<string> {
  const issuedAt = Math.floor(Date.now() / 1000);

  return new SignJWT({ rol: user.rol, sid: user.idFamilia })
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
    requiredClaims: ["sub", "sid", "iat", "exp"],
  });

  const idUsuario = Number(payload.sub);

  if (
    !Number.isSafeInteger(idUsuario) ||
    idUsuario <= 0 ||
    typeof payload.sid !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(payload.sid) ||
    !isRole(payload.rol)
  ) {
    throw new errors.JWTInvalid("Access token con claims inválidos.");
  }

  return {
    idUsuario,
    idFamilia: payload.sid,
    rol: payload.rol,
  };
}
