import type { ErrorRequestHandler } from "express";
import { z, ZodError } from "zod";
import { refreshCookieName, refreshCookieOptions } from "../modules/auth/auth.refresh";

interface SqlError {
  type?: string;
  number?: number;
  message?: string;
  originalError?: {
    info?: {
      number?: number;
      message?: string;
    };
  };
}

export const errorMiddleware: ErrorRequestHandler = (
  error: unknown,
  _req,
  res,
  _next,
) => {
  if (error instanceof ZodError) {
    res.status(400).json({
      error: {
        code: "VALIDATION_ERROR",
        message: "Los datos proporcionados no son válidos",
        details: z.treeifyError(error),
      },
    });
    return;
  }

  if (typeof error === "object" && error !== null) {
    const sqlError = error as SqlError;
    if (sqlError.type === "entity.parse.failed" || sqlError.type === "entity.too.large") {
      const tooLarge = sqlError.type === "entity.too.large";
      res.status(tooLarge ? 413 : 400).json({
        error: {
          code: tooLarge ? "PAYLOAD_TOO_LARGE" : "INVALID_JSON",
          message: tooLarge ? "El cuerpo de la solicitud es demasiado grande." : "El JSON proporcionado no es válido.",
        },
      });
      return;
    }
    const number = sqlError.number ?? sqlError.originalError?.info?.number;
    const message =
      sqlError.message ?? sqlError.originalError?.info?.message ?? "";

    if ([51020, 51022, 51023, 51024].includes(number ?? -1)) {
      res.clearCookie(refreshCookieName, refreshCookieOptions);

      res.status(401).json({
        error: {
          code: "INVALID_REFRESH_TOKEN",
          message: "La sesión expiró o dejó de ser válida.",
        },
      });
      return;
    }

    if (number === 51026 || number === 1205) {
      res.status(503).json({
        error: { code: "SERVICE_UNAVAILABLE", message: "No se pudo procesar la sesión. Intenta más tarde." },
      });
      return;
    }

    if (
      (number === 2601 || number === 2627) &&
      message.includes("UQ_Usuario_Correo")
    ) {
      res.status(409).json({
        error: {
          code: "EMAIL_ALREADY_EXISTS",
          message: "El correo ya está registrado.",
        },
      });
      return;
    }
  }

  // No registrar objetos del driver, bodies, cookies ni mensajes con posibles tokens.
  console.error("Error interno de la aplicación.");

  res.status(500).json({
    error: {
      code: "INTERNAL_ERROR",
      message: "Ocurrió un error interno.",
    },
  });
};
