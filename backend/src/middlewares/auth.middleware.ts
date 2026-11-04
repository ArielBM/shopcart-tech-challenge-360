import type { RequestHandler } from "express";
import { verifyAccessToken } from "../modules/auth/auth.tokens";
import { isRole } from "../modules/auth/auth.types";
import { findUserActiveStatus } from "../modules/auth/auth.repository";

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

  // La validación criptográfica no depende de SQL Server.
  let user;

  try {
    user = await verifyAccessToken(token);
  } catch {
    res.status(401).json({
      error: {
        code: "INVALID_TOKEN",
        message: "Token inválido o expirado.",
      },
    });
    return;
  }

  try {
    const currentUser = await findUserActiveStatus(user.idUsuario);

    if (!currentUser || !currentUser.Activo || !isRole(currentUser.Rol)) {
      res.status(401).json({
        error: {
          code: "USER_INACTIVE",
          message: "La cuenta no está activa o ya no está disponible.",
        },
      });
      return;
    }

    if (user.versionSeguridad !== currentUser.VersionSeguridad) {
      res.status(401).json({
        error: {
          code: "SESSION_REVOKED",
          message: "La sesión dejó de ser válida. Inicia sesión nuevamente.",
        },
      });
      return;
    }

    // Siempre utilizar el rol vigente de SQL Server.
    res.locals.auth = {
      idUsuario: currentUser.IDUsuario,
      rol: currentUser.Rol,
    };

    next();
  } catch (error) {
    // Un error de infraestructura nunca debe tratarse como JWT inválido.
    next(error);
  }
};
