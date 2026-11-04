import axios from "axios";
import type { InternalAxiosRequestConfig } from "axios";
import { api } from "../../lib/api";
import type {
  AuthResponse,
  LoginInput,
  RegisterInput,
  RegisterResponse,
} from "./auth.types";

export async function registerClient(input: RegisterInput) {
  const { data } = await api.post<RegisterResponse>("/auth/register", input);
  return data.data;
}

export async function loginClient(input: LoginInput) {
  const { data } = await api.post<AuthResponse>("/auth/login", input);
  return data.data;
}

export async function refreshClient() {
  const { data } = await api.post<AuthResponse>("/auth/refresh");
  return data.data;
}

export async function logoutClient(): Promise<void> {
  await api.post("/auth/logout");
}

interface AuthHandlers {
  getAccessToken: () => string | null;
  refreshAccessToken: () => Promise<string | null>;
}

type RetryConfig = InternalAxiosRequestConfig & {
  _authRetried?: boolean;
};

function isAuthEndpoint(url?: string): boolean {
  return /\/auth\/(login|register|refresh|logout)(?:[?#]|$)/.test(url ?? "");
}

export function configureAuthInterceptors(handlers: AuthHandlers): () => void {
  const requestId = api.interceptors.request.use((config) => {
    const token = handlers.getAccessToken();

    if (token && !isAuthEndpoint(config.url)) {
      config.headers.set("Authorization", `Bearer ${token}`);
    }

    return config;
  });

  const responseId = api.interceptors.response.use(
    (response) => response,
    async (error: unknown) => {
      if (!axios.isAxiosError(error)) {
        return Promise.reject(error);
      }

      const config = error.config as RetryConfig | undefined;

      if (
        error.response?.status !== 401 ||
        !config ||
        config._authRetried ||
        isAuthEndpoint(config.url)
      ) {
        return Promise.reject(error);
      }

      config._authRetried = true;

      const latestToken = handlers.getAccessToken();
      const attemptedToken = config.headers.get("Authorization");

      // Otra petición pudo haber renovado el token.
      if (latestToken && attemptedToken !== `Bearer ${latestToken}`) {
        config.headers.set("Authorization", `Bearer ${latestToken}`);
        return api(config);
      }

      const newToken = await handlers.refreshAccessToken();

      if (!newToken) {
        return Promise.reject(error);
      }

      config.headers.set("Authorization", `Bearer ${newToken}`);
      return api(config);
    },
  );

  return () => {
    api.interceptors.request.eject(requestId);
    api.interceptors.response.eject(responseId);
  };
}
