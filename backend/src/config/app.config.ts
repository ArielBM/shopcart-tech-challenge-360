import { required } from "./config.utils";

export const appConfig = {
  port: Number(process.env.PORT ?? 3000),
  corsOrigin: required("CORS_ORIGIN"),
};
