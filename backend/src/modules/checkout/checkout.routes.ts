import { Router } from "express";

import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";

import {
  startCheckoutController,
  cancelCheckoutController,
} from "./checkout.controller";

export const checkoutRouter = Router();

checkoutRouter.use(authenticate);
checkoutRouter.use(authorize("CLIENTE"));

checkoutRouter.post("/", startCheckoutController);
checkoutRouter.post("/:idCheckout/cancel", cancelCheckoutController);
