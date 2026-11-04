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
        const session = await refreshClient();

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
    await logoutClient();

    ++sessionVersion;

    set({
      user: null,
      accessToken: null,
      status: "unauthenticated",
    });
  },
}));

configureAuthInterceptors({
  getAccessToken: () => useAuthStore.getState().accessToken,
  refreshAccessToken: () => useAuthStore.getState().restoreSession(),
});
