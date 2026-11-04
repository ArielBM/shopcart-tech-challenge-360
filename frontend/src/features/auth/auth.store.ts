import axios from "axios";
import { create } from "zustand";
import {
  configureAuthInterceptors,
  loginClient,
  logoutClient,
  refreshClient,
} from "./auth.api";
import type { AuthStatus, AuthUser, LoginInput } from "./auth.types";

interface AuthState {
  user: AuthUser | null;
  accessToken: string | null;
  status: AuthStatus;

  login: (input: LoginInput) => Promise<void>;
  restoreSession: () => Promise<string | null>;
  logout: () => Promise<void>;
}

let pendingRefresh: Promise<string | null> | null = null;
let sessionVersion = 0;

// Web Locks coordina pestañas del mismo origen.
const AUTH_LOCK = "shopcart:auth:session";

async function withAuthLock<T>(operation: () => Promise<T>): Promise<T> {
  if (!navigator.locks) {
    throw new Error(
      "El navegador no admite la coordinación segura de sesiones.",
    );
  }

  return navigator.locks.request(AUTH_LOCK, { mode: "exclusive" }, operation);
}

// No se transmiten tokens ni credenciales.
const authChannel =
  typeof BroadcastChannel !== "undefined"
    ? new BroadcastChannel("shopcart:auth")
    : null;

function clearLocalSession(broadcast: boolean): void {
  ++sessionVersion;

  useAuthStore.setState({
    user: null,
    accessToken: null,
    status: "unauthenticated",
  });

  if (broadcast) {
    authChannel?.postMessage({ type: "logout" });
  }
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  accessToken: null,
  status: "idle",

  login: async (input) => {
    const version = ++sessionVersion;
    set({ status: "loading" });

    try {
      const session = await loginClient(input);

      if (version !== sessionVersion) return;

      set({
        user: session.user,
        accessToken: session.accessToken,
        status: "authenticated",
      });
    } catch (error) {
      if (version === sessionVersion) {
        set({
          user: null,
          accessToken: null,
          status: "unauthenticated",
        });
      }

      throw error;
    }
  },

  restoreSession: () => {
    if (pendingRefresh) return pendingRefresh;

    const version = sessionVersion;
    const previousStatus = get().status;

    if (get().status === "idle") {
      set({ status: "loading" });
    }

    const operation = (async (): Promise<string | null> => {
      try {
        // La petición HTTP ocurre DENTRO del bloqueo.
        // La pestaña siguiente recibe la cookie ya rotada.
        const session = await withAuthLock(refreshClient);

        // Descarta resultados que lleguen después de logout/login.
        if (version !== sessionVersion) return null;

        set({
          user: session.user,
          accessToken: session.accessToken,
          status: "authenticated",
        });

        return session.accessToken;
      } catch (error) {
        if (version !== sessionVersion) return null;

        if (axios.isAxiosError(error) && error.response?.status === 401) {
          clearLocalSession(true);
          return null;
        }

        // Error temporal: no hay evidencia de revocación.
        if (previousStatus === "idle") {
          set({ status: "idle" });
        }

        // Conservar la sesión previa y propagar el error.
        throw error;
      }
    })();

    pendingRefresh = operation;

    const clearPending = () => {
      if (pendingRefresh === operation) {
        pendingRefresh = null;
      }
    };

    void operation.then(clearPending, clearPending);

    return operation;
  },

  logout: async () => {
    // Comparte el bloqueo con refresh para impedir
    // la rotación mientras se revoca la cookie.
    await withAuthLock(logoutClient);

    clearLocalSession(true);
  },
}));

// Logout recibido desde otra pestaña.
if (authChannel) {
  authChannel.onmessage = (event: MessageEvent<unknown>) => {
    const message = event.data;

    if (
      typeof message !== "object" ||
      message === null ||
      !("type" in message) ||
      message.type !== "logout"
    ) {
      return;
    }

    clearLocalSession(false);
  };
}

const removeInterceptors = configureAuthInterceptors({
  getAccessToken: () => useAuthStore.getState().accessToken,

  refreshAccessToken: () => useAuthStore.getState().restoreSession(),

  onUserInactive: (attemptedToken) => {
    const currentToken = useAuthStore.getState().accessToken;

    // Una respuesta tardía no debe cerrar una sesión nueva.
    if (currentToken && attemptedToken === `Bearer ${currentToken}`) {
      clearLocalSession(true);
    }
  },
});

// Liberar recursos al reemplazar el módulo durante desarrollo.
if (import.meta.hot) {
  // El store es una frontera HMR explícita.
  // Una actualización requiere reconstruir la sesión.
  import.meta.hot.accept(() => {
    window.location.reload();
  });

  import.meta.hot.dispose(() => {
    authChannel?.close();
    removeInterceptors();
  });
}
