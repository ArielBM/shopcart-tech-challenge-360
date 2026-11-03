import { createHash } from "node:crypto";

import { startPaymentAttempt, confirmPayment } from "./payments.repository";

import type { ProcessPaymentData } from "./payments.schemas";

export async function processPaymentService(
  idUsuario: number,
  idCheckout: string,
  input: ProcessPaymentData,
) {
  const { idDireccion, claveIdempotencia } = input;

  // Misma solicitud = misma huella.
  // Incluye direccion y condiciones fijas del envio.
  const huellaSolicitud = createHash("sha256")
    .update(
      JSON.stringify({
        idUsuario,
        idCheckout,
        idDireccion,
        claveIdempotencia,
        metodoEnvio: "ESTANDAR",
        costoEnvio: "0.00",
      }),
    )
    .digest();

  // SQL Server valida propiedad, reserva y monto.
  // Si existe un intento con la misma clave,
  // recupera el resultado previamente persistido.
  const intento = await startPaymentAttempt({
    idUsuario,
    idCheckout,
    idDireccion,
    claveIdempotencia,
    huellaSolicitud,
  });

  if (intento.Estado === "FALLIDO") {
    return {
      data: {
        idIntentoPago: String(intento.IDIntentoPago),
        idCheckout: String(intento.IDCheckout),
        estado: "FALLIDO",
        monto: String(intento.Monto),
        reutilizado: true,
      },
    };
  }

  // Nunca generar una referencia aleatoria por reintento.
  // La misma operación conserva la misma referencia.
  const referenciaProcesador = `SIM-${String(intento.IDIntentoPago)}`;

  if (intento.Estado !== "PENDIENTE" && intento.Estado !== "EXITOSO") {
    throw new Error("El intento de pago requiere revisión de su estado.");
  }

  // Simulación aprobada.
  // La confirmación es atómica dentro de SQL Server.
  const resultado = await confirmPayment({
    idUsuario,
    idCheckout,
    idDireccion,
    claveIdempotencia,
    huellaSolicitud,
    referenciaProcesador,
  });

  return {
    data: {
      idPedido: String(resultado.IDPedido),
      idIntentoPago: String(resultado.IDIntentoPago),
      idCheckout,
      estado: resultado.Estado,
      monto: String(intento.Monto),
      reutilizado: resultado.Reutilizado,
    },
  };
}
