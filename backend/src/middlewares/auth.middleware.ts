import type { RequestHandler } from "express";
import { verifyAccessToken } from "../modules/auth/auth.tokens";

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

  try {
    const user = await verifyAccessToken(token);
    res.locals.auth = user;
    next();
  } catch {
    res.status(401).json({
      error: {
        code: "INVALID_TOKEN",
        message: "Token inválido o expirado.",
      },
    });
  }
};
