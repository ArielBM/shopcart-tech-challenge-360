export interface CheckoutRecord {
  IDCheckout: string | number;
  Estado: string;
  FechaExpiracion: Date;
  Reutilizado: boolean;
}

export interface CancelCheckoutRecord {
  IDCheckout: string | number;
  Estado: string;
  Cancelado: boolean;
}

export interface StartCheckoutInput {
  idUsuario: number;
  claveInicio: string;
  huellaSolicitud: Buffer;
}

export interface CancelCheckoutInput {
  idUsuario: number;
  idCheckout: string;
}

export interface ExpiredCheckoutsRecord {
  CheckoutsExpirados: number;
}
