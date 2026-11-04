import { useEffect, useState } from "react";
import { BrowserRouter } from "react-router";

import { AppRouter } from "./app/router";
import { useAuthStore } from "./features/auth/auth.store";

function App() {
  const [initializing, setInitializing] = useState(true);

  useEffect(() => {
    let active = true;

    void useAuthStore
      .getState()
      .restoreSession()
      .finally(() => {
        if (active) setInitializing(false);
      });

    return () => {
      active = false;
    };
  }, []);

  if (initializing) {
    return (
      <div
        role="status"
        aria-live="polite"
        className="flex min-h-dvh items-center justify-center bg-canvas text-ink"
      >
        <p className="text-sm text-muted">Cargando sesión...</p>
      </div>
    );
  }

  return (
    <BrowserRouter>
      <AppRouter />
    </BrowserRouter>
  );
}

export default App;
