import { required } from "./config.utils";

const corsOrigin = required("CORS_ORIGIN");
const originUrl = new URL(corsOrigin);
if (
  originUrl.origin !== corsOrigin ||
  !["http:", "https:"].includes(originUrl.protocol) ||
  (process.env.NODE_ENV === "production" && originUrl.protocol !== "https:")
) {
  throw new Error("CORS_ORIGIN debe ser un origen HTTP válido; en producción debe usar HTTPS.");
}

export const appConfig = {
  port: Number(process.env.PORT ?? 3000),
  corsOrigin,
};
