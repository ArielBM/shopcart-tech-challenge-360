import { createHash } from "node:crypto";

import { startCheckout, cancelCheckout } from "./checkout.repository";

export async function startCheckoutService(
  idUsuario: number,
  claveInicio: string,
) {
  const huellaSolicitud = createHash("sha256")
    .update(JSON.stringify({ idUsuario, claveInicio }))
    .digest();

  const checkout = await startCheckout({
    idUsuario,
    claveInicio,
    huellaSolicitud,
  });

  return {
    data: {
      idCheckout: String(checkout.IDCheckout),
      estado: checkout.Estado,
      fechaExpiracion: checkout.FechaExpiracion,
      reutilizado: checkout.Reutilizado,
    },
  };
}

export async function cancelCheckoutService(
  idUsuario: number,
  idCheckout: string,
) {
  const checkout = await cancelCheckout({
    idUsuario,
    idCheckout,
  });

  return {
    data: {
      idCheckout: String(checkout.IDCheckout),
      estado: checkout.Estado,
      cancelado: checkout.Cancelado,
    },
  };
}
