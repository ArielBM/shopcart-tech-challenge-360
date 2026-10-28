import type { RequestHandler } from "express";
import { AccessTokenPayload, Role } from "../modules/auth/auth.types";

export function authorize(...allowedRoles: Role[]): RequestHandler {
  return (_req, res, next) => {
    const auth = res.locals.auth as AccessTokenPayload | undefined;

    if (!auth) {
      res.status(401).json({
        error: {
          code: "UNAUTHORIZED",
          message: "Autenticación requerida.",
        },
      });
      return;
    }

    if (!allowedRoles.includes(auth.rol as Role)) {
      res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "No tienes permisos para realizar esta operación.",
        },
      });
      return;
    }

    next();
  };
}
