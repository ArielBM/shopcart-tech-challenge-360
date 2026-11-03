export interface PaymentInput {
  idCheckout: string;
  idUsuario: number;
  claveIdempotencia: string;
  huellaSolicitud: Buffer;
}

export interface StartPaymentInput extends PaymentInput {
  idDireccion: string;
}

export interface ConfirmPaymentInput extends StartPaymentInput {
  referenciaProcesador: string;
}

export interface PaymentAttemptRecord {
  IDIntentoPago: string | number;
  IDCheckout: string | number;
  Estado: string;
  Monto: string;
  Reutilizado: boolean;
}

export interface FailedPaymentRecord {
  IDIntentoPago: string | number;
  IDCheckout: string | number;
  Estado: string;
  Reutilizado: boolean;
}

export interface ConfirmedPaymentRecord {
  IDPedido: string | number;
  IDIntentoPago: string | number;
  Estado: string;
  Reutilizado: boolean;
}
