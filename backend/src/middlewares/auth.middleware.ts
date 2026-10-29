import type { RequestHandler } from "express";
import { verifyAccessToken } from "../modules/auth/auth.tokens";
import { errors } from "jose";
import { findActiveSession } from "../modules/auth/auth.repository";
import { isRole, type AccessTokenPayload } from "../modules/auth/auth.types";

export const authenticate: RequestHandler = async (req, res, next) => {
  const authorization = req.headers.authorization;

  if (!authorization?.startsWith("Bearer ")) {
    res.status(401).json({
      error: {
        code: "UNAUTHORIZED",
        message: "Token de acceso requerido.",
      },
    });
    return;
  }

  const token = authorization.slice(7);

  if (!token) {
    res.status(401).json({
      error: {
        code: "UNAUTHORIZED",
        message: "Token de acceso requerido.",
      },
    });
    return;
  }

  let payload: AccessTokenPayload;
  try {
    payload = await verifyAccessToken(token);
  } catch (error: unknown) {
    if (!(error instanceof errors.JOSEError)) {
      next(error);
      return;
    }
    res.status(401).json({
      error: {
        code: "INVALID_TOKEN",
        message: "Token inválido o expirado.",
      },
    });
    return;
  }

  // La familia vigente vincula el JWT al logout, replay y vencimiento absoluto.
  const user = await findActiveSession(payload.idUsuario, payload.idFamilia);
  if (!user) {
    res.status(401).json({
      error: { code: "INVALID_TOKEN", message: "Sesión no válida." },
    });
    return;
  }
  if (!isRole(user.Rol)) throw new Error("El usuario tiene un rol no admitido.");
  res.locals.auth = { idUsuario: user.IDUsuario, idFamilia: payload.idFamilia, rol: user.Rol };
  next();
};
