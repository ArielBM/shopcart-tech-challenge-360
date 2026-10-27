import { appConfig } from "./app.config";
import { databaseConfig } from "./database.config";

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  ...appConfig,
  db: databaseConfig,
};
