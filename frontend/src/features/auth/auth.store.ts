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
      } catch {
        if (version === sessionVersion) {
          set({
            user: null,
            accessToken: null,
            status: "unauthenticated",
          });
        }

        return null;
      }
    })();

    pendingRefresh = operation;

    void operation.finally(() => {
      if (pendingRefresh === operation) {
        pendingRefresh = null;
      }
    });

    return operation;
  },

  logout: async () => {
    // Comparte el bloqueo con refresh para impedir
    // la rotación mientras se revoca la cookie.
    await withAuthLock(logoutClient);

    ++sessionVersion;

    set({
      user: null,
      accessToken: null,
      status: "unauthenticated",
    });

    // Avisar a todas las demás pestañas.
    authChannel?.postMessage({ type: "logout" });
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

    ++sessionVersion;

    useAuthStore.setState({
      user: null,
      accessToken: null,
      status: "unauthenticated",
    });
  };
}

const removeInterceptors = configureAuthInterceptors({
  getAccessToken: () => useAuthStore.getState().accessToken,
  refreshAccessToken: () => useAuthStore.getState().restoreSession(),
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
