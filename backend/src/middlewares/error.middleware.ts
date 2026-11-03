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
  // Zod: datos de entrada que no cumplen el esquema de validación.
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

  // Parser de Express: cuerpo JSON malformado (HTTP 400).
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

  // Examina posibles errores del driver SQL; aún no confirma su origen.
  if (typeof error === "object" && error !== null) {
    const sqlError = error as SqlError;
    const number = sqlError.number ?? sqlError.originalError?.info?.number;
    const message =
      sqlError.message ?? sqlError.originalError?.info?.message ?? "";

    // ShopCart (THROW): 51201 = categoría inexistente o inactiva para el producto.
    if (number === 51201) {
      res.status(400).json({
        error: {
          code: "INVALID_PRODUCT_CATEGORY",
          message: "La categoría no existe o está inactiva.",
        },
      });
      return;
    }

    // ShopCart (THROW): 51202 = producto inexistente o no visible en la consulta.
    if (number === 51202) {
      res.status(404).json({
        error: {
          code: "PRODUCT_NOT_FOUND",
          message: "El producto solicitado no existe.",
        },
      });
      return;
    }

    // ShopCart (previsto): 51206 = estado del producto obligatorio.
    // Los SP actuales del repositorio todavía no lanzan este código.
    if (number === 51206) {
      res.status(400).json({
        error: {
          code: "INVALID_PRODUCT_STATUS",
          message: "El estado del producto es obligatorio.",
        },
      });
      return;
    }

    // ShopCart (THROW): 51101 = categoría inexistente.
    if (number === 51101) {
      res.status(404).json({
        error: {
          code: "CATEGORY_NOT_FOUND",
          message: "La categoría solicitada no existe.",
        },
      });
      return;
    }

    // ShopCart (THROW): 51203 = paginación inválida.
    if (number === 51203) {
      res.status(400).json({
        error: {
          code: "INVALID_PAGINATION",
          message: "La paginación proporcionada no es válida.",
        },
      });
      return;
    }

    // ShopCart (THROW): 51204 = formato o rango de precios inválido.
    if (number === 51204) {
      res.status(400).json({
        error: {
          code: "INVALID_PRICE_RANGE",
          message: "El formato o rango de precios proporcionado no es válido.",
        },
      });
      return;
    }

    // Inventario: cantidad de entrada inválida o ajuste igual a cero.
    if (number === 51500 || number === 51506) {
      res.status(400).json({
        error: {
          code: "INVALID_INVENTORY_QUANTITY",
          message: "La cantidad de inventario no es válida.",
        },
      });
      return;
    }

    // Inventario: motivo obligatorio para entradas y ajustes.
    if (number === 51501) {
      res.status(400).json({
        error: {
          code: "INVENTORY_REASON_REQUIRED",
          message: "El motivo del movimiento es obligatorio.",
        },
      });
      return;
    }

    // Inventario: variante inexistente.
    if (number === 51502) {
      res.status(404).json({
        error: {
          code: "INVENTORY_VARIANT_NOT_FOUND",
          message: "La variante solicitada no existe.",
        },
      });
      return;
    }

    // Inventario: ubicación inexistente o inactiva.
    if (number === 51503) {
      res.status(400).json({
        error: {
          code: "INVALID_INVENTORY_LOCATION",
          message: "La ubicación no existe o está inactiva.",
        },
      });
      return;
    }

    // Inventario: bloqueo no adquirido por concurrencia.
    if (number === 51504) {
      res.status(409).json({
        error: {
          code: "INVENTORY_LOCK_CONFLICT",
          message: "El inventario está siendo actualizado. Intenta nuevamente.",
        },
      });
      return;
    }

    // Inventario: la existencia resultante supera el límite INT.
    if (number === 51505) {
      res.status(400).json({
        error: {
          code: "INVENTORY_LIMIT_EXCEEDED",
          message: "La existencia supera el límite permitido.",
        },
      });
      return;
    }

    // Inventario: no existe saldo para la variante y ubicación indicadas.
    if (number === 51507) {
      res.status(404).json({
        error: {
          code: "INVENTORY_NOT_FOUND",
          message: "No existe inventario para esta variante y ubicación.",
        },
      });
      return;
    }

    // Inventario: el ajuste dejaría existencias negativas o inferiores a las reservadas.
    if (number === 51508) {
      res.status(409).json({
        error: {
          code: "INSUFFICIENT_INVENTORY",
          message: "El ajuste supera las existencias disponibles.",
        },
      });
      return;
    }

    // Inventario: identificador de variante o ubicación inválido.
    if (number === 51509 || number === 51510) {
      res.status(400).json({
        error: {
          code: "INVALID_INVENTORY_FILTER",
          message: "El filtro de inventario no es válido.",
        },
      });
      return;
    }

    // Inventario: parámetros de paginación inválidos.
    if (number === 51511) {
      res.status(400).json({
        error: {
          code: "INVALID_PAGINATION",
          message: "La paginación proporcionada no es válida.",
        },
      });
      return;
    }

    // Inventario: fecha inicial posterior a la fecha final.
    if (number === 51512) {
      res.status(400).json({
        error: {
          code: "INVALID_DATE_RANGE",
          message: "El rango de fechas no es válido.",
        },
      });
      return;
    }

    // ShopCart (THROW): 51205 = ordenamiento inválido.
    if (number === 51205) {
      res.status(400).json({
        error: {
          code: "INVALID_SORT_ORDER",
          message: "El ordenamiento proporcionado no es válido.",
        },
      });
      return;
    }

    // ShopCart (THROW): 51022 = token desconocido; 51023 = sesión no vigente;
    // 51024 = reutilización de un refresh token detectada.
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

    // SQL Server: 2601 = duplicado en índice único; 2627 = violación de PK/UNIQUE.
    // Solo se traduce a correo duplicado cuando corresponde a UQ_Usuario_Correo.
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
