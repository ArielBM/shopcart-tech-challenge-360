import { Router } from "express";

import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";

import { processPaymentController } from "./payments.controller";

export const paymentsRouter = Router();

paymentsRouter.use(authenticate);
paymentsRouter.use(authorize("CLIENTE"));

paymentsRouter.post("/:idCheckout/process", processPaymentController);
