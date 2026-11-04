import { useState } from "react";
import type { SubmitEvent } from "react";
import { Link } from "react-router";

import { Button } from "../../../components/ui/Button";
import { PasswordInput } from "../../../components/ui/PasswordInput";
import { TextInput } from "../../../components/ui/TextInput";
import { getApiErrorMessage } from "../../../lib/api";
import { registerClient } from "../auth.api";

export function RegisterPage() {
  const [nombre, setNombre] = useState("");
  const [correo, setCorreo] = useState("");
  const [contrasena, setContrasena] = useState("");
  const [confirmacion, setConfirmacion] = useState("");

  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [registered, setRegistered] = useState(false);

  async function handleSubmit(event: SubmitEvent<HTMLFormElement>) {
    event.preventDefault();
    if (isLoading) return;

    setError(null);

    if (contrasena !== confirmacion) {
      setError("Las contraseñas no coinciden.");
      return;
    }

    setIsLoading(true);

    try {
      await registerClient({
        nombre: nombre.trim(),
        correo: correo.trim().toLowerCase(),
        contrasena,
      });

      setRegistered(true);
    } catch (err) {
      setError(getApiErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  if (registered) {
    return (
      <div className="space-y-5 text-center">
        <h1 className="text-2xl font-bold text-ink">
          Cuenta creada correctamente
        </h1>
        <p className="text-sm text-muted">
          Tu registro se completó. Ya puedes iniciar sesión.
        </p>
        <Link
          to="/login"
          className="inline-flex min-h-11 items-center justify-center rounded-lg bg-brand px-6 py-3 text-sm font-medium text-white hover:bg-brand/90"
        >
          Iniciar sesión
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <header className="space-y-2 text-center">
        <h1 className="text-2xl font-bold text-ink">Crear cuenta</h1>
        <p className="text-sm text-muted">
          Regístrate para comenzar a comprar en ShopCart.
        </p>
      </header>

      <form onSubmit={handleSubmit} className="space-y-5">
        <TextInput
          label="Nombre completo"
          name="nombre"
          autoComplete="name"
          value={nombre}
          onChange={(event) => setNombre(event.target.value)}
          maxLength={150}
          required
          disabled={isLoading}
        />

        <TextInput
          label="Correo electrónico"
          type="email"
          name="correo"
          autoComplete="email"
          value={correo}
          onChange={(event) => setCorreo(event.target.value)}
          maxLength={254}
          required
          disabled={isLoading}
        />

        <PasswordInput
          label="Contraseña"
          name="contrasena"
          autoComplete="new-password"
          helperText="Debe contener entre 8 y 128 caracteres."
          value={contrasena}
          onChange={(event) => setContrasena(event.target.value)}
          minLength={8}
          maxLength={128}
          required
          disabled={isLoading}
        />

        <PasswordInput
          label="Confirmar contraseña"
          name="confirmacion"
          autoComplete="new-password"
          value={confirmacion}
          onChange={(event) => setConfirmacion(event.target.value)}
          minLength={8}
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
          Crear cuenta
        </Button>
      </form>

      <p className="text-center text-sm text-muted">
        ¿Ya tienes una cuenta?{" "}
        <Link to="/login" className="font-semibold text-brand hover:underline">
          Inicia sesión
        </Link>
      </p>
    </div>
  );
}
