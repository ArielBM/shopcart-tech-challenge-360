import type { Request, Response } from "express";

import type { AccessTokenPayload } from "../auth/auth.types";
import {
  changeUserStatusSchema,
  userIdSchema,
  usersQuerySchema,
} from "./users.schemas";
import { changeUserStatusService, getUsersService } from "./users.service";

export async function listUsers(req: Request, res: Response): Promise<void> {
  const filters = usersQuerySchema.parse(req.query);
  const result = await getUsersService(filters);

  res.status(200).json(result);
}

export async function updateUserStatus(
  req: Request,
  res: Response,
): Promise<void> {
  const idUsuario = userIdSchema.parse(req.params.idUsuario);
  const { activo } = changeUserStatusSchema.parse(req.body);

  const auth = res.locals.auth as AccessTokenPayload;

  const user = await changeUserStatusService({
    idUsuario,
    activo,
    idAdministrador: auth.idUsuario,
  });

  res.status(200).json({ data: user });
}
