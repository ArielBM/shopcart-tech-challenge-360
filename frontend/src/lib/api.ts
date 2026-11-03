import axios from "axios";

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  withCredentials: true,
  timeout: 10000,
});

export interface ApiError {
  error: {
    code: string;
    message: string;
  };
}

export function getApiErrorMessage(error: unknown): string {
  if (axios.isAxiosError<ApiError>(error)) {
    return (
      error.response?.data?.error?.message ??
      "No fue posible conectar con el servidor."
    );
  }

  return "Ocurrió un error inesperado.";
}
