import { Router } from "express";
import { authRouter } from "../modules/auth/auth.routes";
import { categoriesRouter } from "../modules/categories/categories.routes";
import { productsRouter } from "../modules/products/products.routes";
import { inventoryRouter } from "../modules/inventory/inventory.routes";
import { cartRouter } from "../modules/cart/cart.routes";
import { checkoutRouter } from "../modules/checkout/checkout.routes";
import { addressesRouter } from "../modules/addresses/addresses.routes";
import { paymentsRouter } from "../modules/payments/payments.routes";

export const apiRouter = Router();

apiRouter.get("/health", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

apiRouter.use("/auth", authRouter);
apiRouter.use("/categories", categoriesRouter);
apiRouter.use("/products", productsRouter);
apiRouter.use("/inventory", inventoryRouter);
apiRouter.use("/cart", cartRouter);
apiRouter.use("/checkout", checkoutRouter);
apiRouter.use("/addresses", addressesRouter);
apiRouter.use("/payments", paymentsRouter);
