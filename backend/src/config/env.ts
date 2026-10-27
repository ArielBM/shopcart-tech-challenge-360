const nodeEnv = process.env.NODE_ENV ?? "development";

if (nodeEnv !== "development" && nodeEnv !== "production") {
  throw new Error(`NODE_ENV inválido: ${nodeEnv}`);
}

function required(name: string): string {
  const value = process.env[name];

  if (!value?.trim()) {
    throw new Error(`Variable de entorno requerida: ${name}`);
  }

  return value;
}

export const env = {
  nodeEnv: nodeEnv,
  port: Number(process.env.PORT ?? 3000),
  corsOrigin: required("CORS_ORIGIN"),
  db: {
    server: required("DB_SERVER"),
    port: Number(process.env.DB_PORT ?? 1433),
    database: required("DB_NAME"),
    encrypt: process.env.DB_ENCRYPT !== "false",
    trustServerCertificate: process.env.DB_TRUST_SERVER_CERTIFICATE === "true",
  },
};
