import { Router } from "express";

import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";
import {
  getCartController,
  addCartItemController,
  updateCartItemController,
  deleteCartItemController,
} from "./cart.controller";

export const cartRouter = Router();

cartRouter.use(authenticate);
cartRouter.use(authorize("CLIENTE"));

cartRouter.get("/", getCartController);
cartRouter.post("/items", addCartItemController);
cartRouter.patch("/items/:idVariante", updateCartItemController);
cartRouter.delete("/items/:idVariante", deleteCartItemController);
