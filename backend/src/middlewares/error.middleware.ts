import type { ErrorRequestHandler, Response } from "express";
import { z, ZodError } from "zod";

interface HttpErrorResponse {
  readonly status: number;
  readonly code: string;
  readonly message: string;
}

interface SqlErrorDetails {
  number: number | undefined;
  message: string;
}

const invalidRefreshTokenError: HttpErrorResponse = {
  status: 401,
  code: "INVALID_REFRESH_TOKEN",
  message: "La sesión expiró o dejó de ser válida.",
};

const invalidInventoryQuantityError: HttpErrorResponse = {
  status: 400,
  code: "INVALID_INVENTORY_QUANTITY",
  message: "La cantidad de inventario no es válida.",
};

const invalidInventoryFilterError: HttpErrorResponse = {
  status: 400,
  code: "INVALID_INVENTORY_FILTER",
  message: "El filtro de inventario no es válido.",
};

// Traducciones de THROW a respuestas públicas, agrupadas por módulo.
const sqlErrorResponses: Readonly<Partial<Record<number, HttpErrorResponse>>> =
  {
    // Catálogo: categorías.
    51101: {
      status: 404,
      code: "CATEGORY_NOT_FOUND",
      message: "La categoría solicitada no existe.",
    },
    // Catálogo: productos.
    51201: {
      status: 400,
      code: "INVALID_PRODUCT_CATEGORY",
      message: "La categoría no existe o está inactiva.",
    },
    51202: {
      status: 404,
      code: "PRODUCT_NOT_FOUND",
      message: "El producto solicitado no existe.",
    },
    51203: {
      status: 400,
      code: "INVALID_PAGINATION",
      message: "La paginación proporcionada no es válida.",
    },
    51204: {
      status: 400,
      code: "INVALID_PRICE_RANGE",
      message: "El formato o rango de precios proporcionado no es válido.",
    },
    51205: {
      status: 400,
      code: "INVALID_SORT_ORDER",
      message: "El ordenamiento proporcionado no es válido.",
    },
    // Previsto: los SP actuales todavía no lanzan 51206.
    51206: {
      status: 400,
      code: "INVALID_PRODUCT_STATUS",
      message: "El estado del producto es obligatorio.",
    },
    // Inventario.
    51500: invalidInventoryQuantityError,
    51501: {
      status: 400,
      code: "INVENTORY_REASON_REQUIRED",
      message: "El motivo del movimiento es obligatorio.",
    },
    51502: {
      status: 404,
      code: "INVENTORY_VARIANT_NOT_FOUND",
      message: "La variante solicitada no existe.",
    },
    51503: {
      status: 400,
      code: "INVALID_INVENTORY_LOCATION",
      message: "La ubicación no existe o está inactiva.",
    },
    51504: {
      status: 409,
      code: "INVENTORY_LOCK_CONFLICT",
      message: "El inventario está siendo actualizado. Intenta nuevamente.",
    },
    51505: {
      status: 400,
      code: "INVENTORY_LIMIT_EXCEEDED",
      message: "La existencia supera el límite permitido.",
    },
    51506: invalidInventoryQuantityError,
    51507: {
      status: 404,
      code: "INVENTORY_NOT_FOUND",
      message: "No existe inventario para esta variante y ubicación.",
    },
    51508: {
      status: 409,
      code: "INSUFFICIENT_INVENTORY",
      message: "El ajuste supera las existencias disponibles.",
    },
    51509: invalidInventoryFilterError,
    51510: invalidInventoryFilterError,
    51511: {
      status: 400,
      code: "INVALID_PAGINATION",
      message: "La paginación proporcionada no es válida.",
    },
    51512: {
      status: 400,
      code: "INVALID_DATE_RANGE",
      message: "El rango de fechas no es válido.",
    },
    // Carrito.
    51600: {
      status: 400,
      code: "INVALID_CART_QUANTITY",
      message: "La cantidad debe ser un entero positivo.",
    },
    51601: {
      status: 400,
      code: "INVALID_CART_OWNER",
      message: "El propietario del carrito no es válido.",
    },
    51602: {
      status: 409,
      code: "CART_LOCK_CONFLICT",
      message: "El carrito está ocupado. Intenta nuevamente.",
    },
    51603: {
      status: 409,
      code: "CART_VARIANT_UNAVAILABLE",
      message: "La variante no está disponible para la compra.",
    },
    51604: {
      status: 409,
      code: "CART_LOCATION_UNAVAILABLE",
      message: "La bodega central no está disponible.",
    },
    51605: {
      status: 409,
      code: "CART_INVENTORY_LOCK_CONFLICT",
      message: "No se pudo consultar el inventario. Intenta nuevamente.",
    },
    51606: {
      status: 409,
      code: "INSUFFICIENT_STOCK",
      message: "No hay existencias suficientes para la cantidad solicitada.",
    },
    51607: {
      status: 409,
      code: "CART_QUANTITY_LIMIT",
      message: "La cantidad acumulada supera el límite permitido.",
    },
    51608: {
      status: 404,
      code: "CART_NOT_FOUND",
      message: "No existe un carrito activo.",
    },
    51609: {
      status: 404,
      code: "CART_ITEM_NOT_FOUND",
      message: "La variante no existe en el carrito.",
    },
    51610: {
      status: 400,
      code: "INVALID_CART_VARIANT",
      message: "El identificador de variante no es válido.",
    },
    // Checkout: inicio y reservas.
    51700: {
      status: 400,
      code: "INVALID_CHECKOUT_CUSTOMER",
      message: "El cliente no es válido.",
    },
    51701: {
      status: 400,
      code: "INVALID_CHECKOUT_REQUEST",
      message: "Los datos de inicio del checkout no son válidos.",
    },
    51702: {
      status: 409,
      code: "CHECKOUT_LOCK_CONFLICT",
      message: "El checkout está ocupado. Intenta nuevamente.",
    },
    51703: {
      status: 409,
      code: "CHECKOUT_IDEMPOTENCY_CONFLICT",
      message: "La clave ya fue utilizada para otra solicitud.",
    },
    51704: {
      status: 409,
      code: "CART_LOCK_CONFLICT",
      message: "El carrito está ocupado. Intenta nuevamente.",
    },
    51705: {
      status: 404,
      code: "CART_NOT_FOUND",
      message: "No existe un carrito activo.",
    },
    51706: {
      status: 400,
      code: "CART_EMPTY",
      message: "Agrega productos antes de iniciar el checkout.",
    },
    51707: {
      status: 409,
      code: "CHECKOUT_ALREADY_ACTIVE",
      message: "El carrito ya tiene un checkout activo.",
    },
    51708: {
      status: 409,
      code: "CART_LOCATION_UNAVAILABLE",
      message: "La bodega central no está disponible.",
    },
    51709: {
      status: 409,
      code: "CART_VARIANT_UNAVAILABLE",
      message: "Una variante del carrito ya no está disponible.",
    },
    51710: {
      status: 409,
      code: "INVENTORY_LOCK_CONFLICT",
      message: "El inventario está ocupado. Intenta nuevamente.",
    },
    51711: {
      status: 409,
      code: "INSUFFICIENT_STOCK",
      message: "No hay existencias suficientes para completar la compra.",
    },
    // Checkout: cancelación.
    51730: {
      status: 400,
      code: "INVALID_CHECKOUT_ID",
      message: "Los identificadores no son válidos.",
    },
    51731: {
      status: 404,
      code: "CHECKOUT_NOT_FOUND",
      message: "El checkout solicitado no existe.",
    },
    51732: {
      status: 409,
      code: "CART_LOCK_CONFLICT",
      message: "El carrito está ocupado. Intenta nuevamente.",
    },
    51733: {
      status: 409,
      code: "CHECKOUT_NOT_CANCELLABLE",
      message: "El checkout no puede cancelarse en su estado actual.",
    },
    51734: {
      status: 409,
      code: "CHECKOUT_EXPIRED",
      message: "El checkout ya venció.",
    },
    51735: {
      status: 409,
      code: "CHECKOUT_HAS_ORDER",
      message: "El checkout ya tiene un pedido asociado.",
    },
    51736: {
      status: 409,
      code: "INVENTORY_LOCK_CONFLICT",
      message: "El inventario está ocupado. Intenta nuevamente.",
    },
    51737: {
      status: 409,
      code: "INVENTORY_RESERVATION_CONFLICT",
      message: "Las existencias reservadas son inconsistentes.",
    },
    51738: {
      status: 409,
      code: "CHECKOUT_RESERVATION_CONFLICT",
      message: "La reserva cambió de estado.",
    },
    51739: {
      status: 409,
      code: "CHECKOUT_STATE_CONFLICT",
      message: "El checkout cambió de estado.",
    },
    // Direcciones.
    51800: {
      status: 400,
      code: "INVALID_ADDRESS_CUSTOMER",
      message: "El identificador del cliente no es válido.",
    },
    51801: {
      status: 400,
      code: "INVALID_ADDRESS_DATA",
      message: "Los campos obligatorios de la dirección no son válidos.",
    },
    51802: {
      status: 403,
      code: "ADDRESS_CUSTOMER_UNAVAILABLE",
      message: "El cliente no está autorizado para registrar direcciones.",
    },
    51712: {
      status: 409,
      code: "CHECKOUT_EXPIRATION_PENDING",
      message:
        "La reserva anterior venció. Intenta nuevamente en unos segundos.",
    },
    51713: {
      status: 422,
      code: "CHECKOUT_AMOUNT_OUT_OF_RANGE",
      message: "El importe de un producto excede el límite permitido.",
    },
    51611: {
      status: 409,
      code: "CART_CHECKOUT_ACTIVE",
      message:
        "No puedes modificar el carrito mientras exista un checkout pendiente. Cancélalo o espera a que expire.",
    },
  };

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function getSqlErrorDetails(error: unknown): SqlErrorDetails {
  if (!isObject(error)) {
    return { number: undefined, message: "" };
  }

  const originalError = isObject(error.originalError)
    ? error.originalError
    : undefined;
  const info = isObject(originalError?.info) ? originalError.info : undefined;
  const number = error.number ?? info?.number;
  const message = error.message ?? info?.message;

  return {
    number: typeof number === "number" ? number : undefined,
    message: typeof message === "string" ? message : "",
  };
}

function resolveSqlError({
  number,
  message,
}: SqlErrorDetails): HttpErrorResponse | undefined {
  // Los duplicados ajenos al correo conservan el error genérico.
  if (
    (number === 2601 || number === 2627) &&
    message.includes("UQ_Usuario_Correo")
  ) {
    return {
      status: 409,
      code: "EMAIL_ALREADY_EXISTS",
      message: "El correo ya está registrado.",
    };
  }

  return number === undefined ? undefined : sqlErrorResponses[number];
}

function sendErrorResponse(res: Response, error: HttpErrorResponse): void {
  res.status(error.status).json({
    error: {
      code: error.code,
      message: error.message,
    },
  });
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
    sendErrorResponse(res, {
      status: 400,
      code: "INVALID_JSON",
      message: "El cuerpo de la solicitud contiene JSON inválido.",
    });
    return;
  }

  const sqlError = getSqlErrorDetails(error);

  // La sesión inválida también debe retirar la cookie del navegador.
  if ([51022, 51023, 51024].includes(sqlError.number ?? -1)) {
    res.clearCookie("refreshToken", {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/api/v1/auth",
    });
    sendErrorResponse(res, invalidRefreshTokenError);
    return;
  }

  const sqlErrorResponse = resolveSqlError(sqlError);

  if (sqlErrorResponse) {
    sendErrorResponse(res, sqlErrorResponse);
    return;
  }

  console.error("Error interno de la aplicación.");
  sendErrorResponse(res, {
    status: 500,
    code: "INTERNAL_ERROR",
    message: "Ocurrió un error interno.",
  });
};
