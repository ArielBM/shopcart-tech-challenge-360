import type { ErrorRequestHandler } from "express";
import { z, ZodError } from "zod";

interface SqlError {
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

  if (
    error instanceof SyntaxError &&
    "status" in error &&
    error.status === 400 &&
    "type" in error &&
    error.type === "entity.parse.failed"
  ) {
    res.status(400).json({
      error: {
        code: "INVALID_JSON",
        message: "El cuerpo de la solicitud contiene JSON inválido.",
      },
    });
    return;
  }

  if (typeof error === "object" && error !== null) {
    const sqlError = error as SqlError;
    const number = sqlError.number ?? sqlError.originalError?.info?.number;
    const message =
      sqlError.message ?? sqlError.originalError?.info?.message ?? "";

    if (number === 51101) {
      res.status(404).json({
        error: {
          code: "CATEGORY_NOT_FOUND",
          message: "La categoría solicitada no existe.",
        },
      });
      return;
    }

    if ([51022, 51023, 51024].includes(number ?? -1)) {
      res.clearCookie("refreshToken", {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        path: "/api/v1/auth",
      });

      res.status(401).json({
        error: {
          code: "INVALID_REFRESH_TOKEN",
          message: "La sesión expiró o dejó de ser válida.",
        },
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

  console.error("Error interno de la aplicación.");

  res.status(500).json({
    error: {
      code: "INTERNAL_ERROR",
      message: "Ocurrió un error interno.",
    },
  });
};
