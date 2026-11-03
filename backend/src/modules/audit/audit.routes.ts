
import { Router } from "express";

import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";

import { listAuditRecords } from "./audit.controller";

export const auditRouter = Router();

auditRouter.use(authenticate);
auditRouter.use(authorize("ADMINISTRADOR"));

auditRouter.get("/", listAuditRecords);
