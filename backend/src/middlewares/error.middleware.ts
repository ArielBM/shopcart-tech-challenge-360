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

  if (typeof error === "object" && error !== null) {
    const sqlError = error as SqlError;
    const number = sqlError.number ?? sqlError.originalError?.info?.number;
    const message =
      sqlError.message ?? sqlError.originalError?.info?.message ?? "";

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

    console.error("Error interno:", error);

    res.status(500).json({
      error: {
        code: "INTERNAL_ERROR",
        message: "Ocurrió un error interno.",
      },
    });
  }
};
