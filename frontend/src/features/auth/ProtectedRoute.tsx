import { Link, Navigate, Outlet, useLocation } from "react-router";
import { useAuthStore } from "./auth.store";
import type { UserRole } from "./auth.types";

interface ProtectedRouteProps {
  allowedRoles?: readonly UserRole[];
}

export function ProtectedRoute({ allowedRoles }: ProtectedRouteProps) {
  const user = useAuthStore((state) => state.user);
  const status = useAuthStore((state) => state.status);
  const location = useLocation();

  if (status === "idle" || status === "loading") {
    return (
      <div role="status" className="p-8 text-center text-muted">
        Verificando sesión...
      </div>
    );
  }

  if (status !== "authenticated" || !user) {
    return (
      <Navigate
        to="/login"
        replace
        state={{
          from: location.pathname + location.search + location.hash,
        }}
      />
    );
  }

  if (allowedRoles && !allowedRoles.includes(user.rol)) {
    return (
      <main className="flex min-h-dvh flex-col items-center justify-center gap-4 bg-canvas px-6 text-center">
        <h1 className="text-4xl font-bold text-danger">403</h1>
        <h2 className="text-xl font-semibold text-ink">Acceso denegado</h2>
        <p className="text-muted">
          No tienes permisos para acceder a esta sección.
        </p>
        <Link to="/" className="font-medium text-brand hover:underline">
          Volver a la tienda
        </Link>
      </main>
    );
  }

  return <Outlet />;
}
