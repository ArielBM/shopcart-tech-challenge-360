import { app } from "./app";
import { env } from "./config/env";
import { getConnection } from "./database/connection";
import { startCheckoutExpiration } from "./modules/checkout/checkout.expiration";

async function start(): Promise<void> {
  try {
    await getConnection();

    console.log("Conexión a SQL Server establecida");

    app.listen(env.port, () => {
      console.log(
        `ShopCart(${env.nodeEnv}) API: http://localhost:${String(env.port)}`,
      );

      startCheckoutExpiration();
    });
  } catch (error: unknown) {
    console.error("Error al iniciar ShopCart:", error);
    process.exitCode = 1;
  }
}

void start();
