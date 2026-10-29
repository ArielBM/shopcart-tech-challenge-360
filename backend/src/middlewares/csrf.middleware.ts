import type { RequestHandler } from "express";
import { env } from "../config/env";

// Incluye login: una cookie de sesión también puede ser objetivo de login CSRF.
export const protectAuthRequest: RequestHandler = (req, res, next) => {
  if (
    req.get("Origin") !== env.corsOrigin ||
    req.get("X-CSRF-Protection") !== "1"
  ) {
    res.status(403).json({
      error: {
        code: "FORBIDDEN",
        message: "Origen o protección CSRF no válidos.",
      },
    });
    return;
  }
  next();
};
