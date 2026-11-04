import { Router } from "express";

import { authenticate } from "../../middlewares/auth.middleware";
import { authorize } from "../../middlewares/authorize.middleware";

import { listUsers, updateUserStatus } from "./users.controller";

export const usersRouter = Router();

usersRouter.use(authenticate);
usersRouter.use(authorize("ADMINISTRADOR"));

usersRouter.get("/", listUsers);
usersRouter.patch("/:idUsuario/status", updateUserStatus);
