import { useState } from "react";
import { Link, useNavigate } from "react-router";

import { Button } from "../../components/ui/Button";
import { getApiErrorMessage } from "../../lib/api";
import { useAuthStore } from "./auth.store";

export function AccountActions() {
  const navigate = useNavigate();

  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleLogout() {
    if (isLoading) return;

    setIsLoading(true);
    setError(null);

    try {
      await logout();
      navigate("/login", { replace: true });
    } catch (err) {
      setError(getApiErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  if (!user) {
    return (
      <Link
        to="/login"
        className="inline-flex min-h-11 items-center rounded-lg px-4 text-sm font-medium text-brand hover:bg-brand-soft"
      >
        Iniciar sesión
      </Link>
    );
  }

  return (
    <div className="flex min-w-0 flex-wrap items-center gap-3">
      <span className="max-w-40 truncate text-sm text-ink">{user.nombre}</span>

      <Button
        variant="outline"
        size="sm"
        isLoading={isLoading}
        onClick={() => void handleLogout()}
      >
        Cerrar sesión
      </Button>

      {error && (
        <p role="alert" className="w-full text-sm text-danger">
          {error}
        </p>
      )}
    </div>
  );
}
