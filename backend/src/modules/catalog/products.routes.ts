import { Router } from "express";
import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";

import {
  createProduct,
  updateProduct,
  listProducts,
} from "./products.controller";

export const productsRouter = Router();

productsRouter.get(
  "/admin",
  authenticate,
  authorize("ADMINISTRADOR"),
  (_req, res, next) => {
    res.locals.adminCatalog = true;
    next();
  },
  listProducts,
);

productsRouter.get("/", listProducts);

productsRouter.post(
  "/",
  authenticate,
  authorize("ADMINISTRADOR"),
  createProduct,
);

productsRouter.put(
  "/:idProducto",
  authenticate,
  authorize("ADMINISTRADOR"),
  updateProduct,
);
