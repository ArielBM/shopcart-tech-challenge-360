import { Router } from "express";
import { authRouter } from "../modules/auth/auth.routes";
import { categoriesRouter } from "../modules/catalog/categories.routes";
import { productsRouter } from "../modules/catalog/products.routes";
import { inventoryRouter } from "../modules/inventory/inventory.routes";
import { cartRouter } from "../modules/cart/cart.routes";
import { checkoutRouter } from "../modules/checkout/checkout.routes";

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
