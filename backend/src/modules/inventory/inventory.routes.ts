import { Router } from "express";

import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";

import {
  registerInventoryEntry,
  registerInventoryAdjustment,
  listInventoryStock,
  listInventoryKardex,
} from "./inventory.controller";

export const inventoryRouter = Router();

inventoryRouter.use(authenticate);
inventoryRouter.use(authorize("OPERADOR", "ADMINISTRADOR"));

inventoryRouter.post("/entries", registerInventoryEntry);
inventoryRouter.post("/adjustments", registerInventoryAdjustment);
inventoryRouter.get("/", listInventoryStock);
inventoryRouter.get("/kardex", listInventoryKardex);
