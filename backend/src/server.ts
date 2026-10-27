import { app } from "./app";
import { env } from "./config/env";

app.listen(env.port, () => {
  console.log(
    `ShopCart(${env.nodeEnv}) API: http://localhost:${String(env.port)}`,
  );
});
