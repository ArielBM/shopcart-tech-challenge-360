import { SignJWT, jwtVerify } from "jose";
import { authConfig } from "../../config/auth.config";
import { AccessTokenPayload } from "./auth.types";

export async function createAccessToken(
  user: AccessTokenPayload,
): Promise<string> {
  return new SignJWT({ rol: user.rol })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setSubject(String(user.idUsuario))
    .setIssuer(authConfig.jwtIssuer)
    .setAudience(authConfig.jwtAudience)
    .setIssuedAt()
    .setExpirationTime(authConfig.accessTokenExpiration)
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
    typeof payload.rol !== "string"
  ) {
    throw new Error("Access token con claims inválidos.");
  }

  return {
    idUsuario,
    rol: payload.rol,
  };
}
