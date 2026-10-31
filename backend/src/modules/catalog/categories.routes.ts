import { Router } from "express";

import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";

import {
  createCategory,
  listCategories,
  updateCategory,
} from "./categories.controller";

export const categoriesRouter = Router();

categoriesRouter.post(
  "/",
  authenticate,
  authorize("ADMINISTRADOR"),
  createCategory,
);

categoriesRouter.put(
  "/:idCategoria",
  authenticate,
  authorize("ADMINISTRADOR"),
  updateCategory,
);

categoriesRouter.get(
  "/admin",
  authenticate,
  authorize("ADMINISTRADOR"),
  listCategories,
);

categoriesRouter.get(
  "/",
  (_req, res, next) => {
    res.locals.publicCatalog = true;
    next();
  },
  listCategories,
);
