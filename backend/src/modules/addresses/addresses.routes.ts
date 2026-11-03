import { Router } from "express";

import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";

import {
  createAddressController,
  getAddressesController,
} from "./addresses.controller";

export const addressesRouter = Router();

addressesRouter.use(authenticate);
addressesRouter.use(authorize("CLIENTE"));

addressesRouter.post("/", createAddressController);
addressesRouter.get("/", getAddressesController);
