import sql from "mssql";
import { getConnection } from "../../database/connection";

import type {
  StartPaymentInput,
  PaymentInput,
  ConfirmPaymentInput,
  PaymentAttemptRecord,
  FailedPaymentRecord,
  ConfirmedPaymentRecord,
} from "./payments.types";

export async function startPaymentAttempt(
  input: StartPaymentInput,
): Promise<PaymentAttemptRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDCheckout", sql.BigInt, input.idCheckout)
    .input("IDUsuario", sql.Int, input.idUsuario)
    .input("IDDireccion", sql.BigInt, input.idDireccion)
    .input("ClaveIdempotencia", sql.UniqueIdentifier, input.claveIdempotencia)
    .input("HuellaSolicitud", sql.VarBinary(32), input.huellaSolicitud)
    .execute<PaymentAttemptRecord>("dbo.SP_Pagos_IniciarIntento");

  const attempt = result.recordset[0];

  if (!attempt) {
    throw new Error("No se obtuvo el intento de pago.");
  }

  return attempt;
}

export async function registerFailedPayment(
  input: PaymentInput,
): Promise<FailedPaymentRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDCheckout", sql.BigInt, input.idCheckout)
    .input("IDUsuario", sql.Int, input.idUsuario)
    .input("ClaveIdempotencia", sql.UniqueIdentifier, input.claveIdempotencia)
    .input("HuellaSolicitud", sql.VarBinary(32), input.huellaSolicitud)
    .execute<FailedPaymentRecord>("dbo.SP_Pagos_RegistrarFallo");

  const attempt = result.recordset[0];

  if (!attempt) {
    throw new Error("No se obtuvo el resultado del pago fallido.");
  }

  return attempt;
}

export async function confirmPayment(
  input: ConfirmPaymentInput,
): Promise<ConfirmedPaymentRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDCheckout", sql.BigInt, input.idCheckout)
    .input("IDUsuario", sql.Int, input.idUsuario)
    .input("IDDireccion", sql.BigInt, input.idDireccion)
    .input("ClaveIdempotencia", sql.UniqueIdentifier, input.claveIdempotencia)
    .input("HuellaSolicitud", sql.VarBinary(32), input.huellaSolicitud)
    .input("ReferenciaProcesador", sql.VarChar(100), input.referenciaProcesador)
    .input("MetodoEnvio", sql.NVarChar(80), "ESTANDAR")
    .input("CostoEnvio", sql.Decimal(18, 2), 0)
    .execute<ConfirmedPaymentRecord>("dbo.SP_Checkout_ConfirmarPago");

  const payment = result.recordset[0];

  if (!payment) {
    throw new Error("No se obtuvo la confirmación del pago.");
  }

  return payment;
}
