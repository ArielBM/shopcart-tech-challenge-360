import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router";
import type { SubmitEvent } from "react";

import { Button } from "../../../components/ui/Button";
import { PasswordInput } from "../../../components/ui/PasswordInput";
import { TextInput } from "../../../components/ui/TextInput";
import { getApiErrorMessage } from "../../../lib/api";
import { useAuthStore } from "../auth.store";

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const login = useAuthStore((state) => state.login);
  const status = useAuthStore((state) => state.status);

  const [correo, setCorreo] = useState("");
  const [contrasena, setContrasena] = useState("");
  const [error, setError] = useState<string | null>(null);

  const isLoading = status === "loading";

  async function handleSubmit(event: SubmitEvent<HTMLFormElement>) {
    event.preventDefault();

    if (isLoading) return;

    setError(null);

    try {
      await login({
        correo: correo.trim().toLowerCase(),
        contrasena,
      });

      const user = useAuthStore.getState().user;

      const requestedPath = (location.state as { from?: unknown } | null)?.from;

      const defaultPath =
        user?.rol === "ADMINISTRADOR" || user?.rol === "OPERADOR"
          ? "/admin"
          : "/";

      const destination =
        typeof requestedPath === "string" &&
        requestedPath.startsWith("/") &&
        !requestedPath.startsWith("//") &&
        !requestedPath.startsWith("/\\")
          ? requestedPath
          : defaultPath;

      navigate(destination, { replace: true });
    } catch (err) {
      setError(getApiErrorMessage(err));
    }
  }

  return (
    <div className="space-y-6">
      <header className="space-y-2 text-center">
        <h1 className="text-2xl font-bold text-ink">Iniciar sesión</h1>
        <p className="text-sm text-muted">
          Ingresa tus credenciales para acceder a ShopCart.
        </p>
      </header>

      <form onSubmit={handleSubmit} className="space-y-5">
        <TextInput
          label="Correo electrónico"
          type="email"
          name="correo"
          autoComplete="email"
          placeholder="correo@ejemplo.com"
          value={correo}
          onChange={(event) => setCorreo(event.target.value)}
          maxLength={254}
          required
          disabled={isLoading}
        />

        <PasswordInput
          label="Contraseña"
          name="contrasena"
          autoComplete="current-password"
          value={contrasena}
          onChange={(event) => setContrasena(event.target.value)}
          maxLength={128}
          required
          disabled={isLoading}
        />

        {error && (
          <p
            role="alert"
            className="rounded-lg border border-danger/30 bg-danger/5 p-3 text-sm text-danger"
          >
            {error}
          </p>
        )}

        <Button type="submit" className="w-full" isLoading={isLoading}>
          Iniciar sesión
        </Button>
      </form>

      <p className="text-center text-sm text-muted">
        ¿Todavía no tienes una cuenta?{" "}
        <Link
          to="/register"
          className="font-semibold text-brand hover:underline"
        >
          Regístrate
        </Link>
      </p>
    </div>
  );
}
