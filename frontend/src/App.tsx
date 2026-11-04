import { useEffect, useState } from "react";
import { BrowserRouter } from "react-router";

import { AppRouter } from "./app/router";
import { useAuthStore } from "./features/auth/auth.store";

type InitializationState = "loading" | "ready" | "error";

function App() {
  const [initialization, setInitialization] =
    useState<InitializationState>("loading");

  useEffect(() => {
    let active = true;

    void useAuthStore
      .getState()
      .restoreSession()
      .then(
        () => {
          if (active) setInitialization("ready");
        },
        () => {
          if (active) setInitialization("error");
        },
      );

    return () => {
      active = false;
    };
  }, []);

  async function retryInitialization() {
    setInitialization("loading");

    try {
      await useAuthStore.getState().restoreSession();
      setInitialization("ready");
    } catch {
      setInitialization("error");
    }
  }

  if (initialization === "loading") {
    return (
      <div
        role="status"
        aria-live="polite"
        className="flex min-h-dvh items-center justify-center bg-canvas"
      >
        <p className="text-sm text-muted">Cargando sesión...</p>
      </div>
    );
  }

  if (initialization === "error") {
    return (
      <main className="flex min-h-dvh flex-col items-center justify-center gap-4 bg-canvas px-6 text-center">
        <h1 className="text-xl font-semibold text-ink">
          No pudimos verificar tu sesión
        </h1>

        <p className="max-w-md text-sm text-muted">
          Hay un problema temporal de conexión o disponibilidad. Tu sesión no se
          ha cerrado.
        </p>

        <button
          type="button"
          onClick={() => void retryInitialization()}
          className="rounded-lg bg-brand px-5 py-3 text-sm font-medium text-white hover:opacity-90"
        >
          Reintentar conexión
        </button>
      </main>
    );
  }

  return (
    <BrowserRouter>
      <AppRouter />
    </BrowserRouter>
  );
}

export default App;
