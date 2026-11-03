import sql from "mssql";
import { getConnection } from "../../database/connection";

import type {
  CheckoutRecord,
  CancelCheckoutRecord,
  StartCheckoutInput,
  CancelCheckoutInput,
} from "./checkout.types";

export async function startCheckout({
  idUsuario,
  claveInicio,
  huellaSolicitud,
}: StartCheckoutInput): Promise<CheckoutRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDUsuario", sql.Int, idUsuario)
    .input("ClaveInicio", sql.UniqueIdentifier, claveInicio)
    .input("HuellaSolicitud", sql.VarBinary(32), huellaSolicitud)
    .execute<CheckoutRecord>("dbo.SP_Checkout_Iniciar");

  const checkout = result.recordset[0];

  if (!checkout) {
    throw new Error("El inicio de checkout no devolvió un resultado.");
  }

  return checkout;
}

export async function cancelCheckout({
  idUsuario,
  idCheckout,
}: CancelCheckoutInput): Promise<CancelCheckoutRecord> {
  const pool = await getConnection();

  const result = await pool
    .request()
    .input("IDCheckout", sql.BigInt, idCheckout)
    .input("IDUsuario", sql.Int, idUsuario)
    .execute<CancelCheckoutRecord>("dbo.SP_Checkout_Cancelar");

  const checkout = result.recordset[0];

  if (!checkout) {
    throw new Error("La cancelación del checkout no devolvió un resultado.");
  }

  return checkout;
}
