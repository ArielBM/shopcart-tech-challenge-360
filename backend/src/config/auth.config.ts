import { required } from "./config.utils";

const secret = Buffer.from(required("JWT_SECRET_BASE64"), "base64");

if (secret.length !== 32) {
  throw new Error("JWT_SECRET_BASE64 debe contener 32 bytes en Base64.");
}

export const authConfig = {
  jwtSecret: secret,
  jwtIssuer: "shopcart-api",
  jwtAudience: "shopcart-client",
  accessTokenExpirationSeconds: 15 * 60,
  refreshTokenExpirationDays: 7,
} as const;
