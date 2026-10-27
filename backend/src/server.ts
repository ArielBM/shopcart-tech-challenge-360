import { app } from "./app";
import { env } from "./config/env";
import { getConnection } from "./database/connection";

async function start(): Promise<void> {
  try {
    await getConnection();

    console.log("Conexión a SQL Server establecida");

    app.listen(env.port, () => {
      console.log(`ShopCart API: http://localhost:${String(env.port)}`);
    });
  } catch (error: unknown) {
    console.error("Error al iniciar ShopCart:", error);
    process.exitCode = 1;
  }
}

void start();
