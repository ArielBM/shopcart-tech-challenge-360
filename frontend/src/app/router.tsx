import { Route, Routes } from "react-router";
import {
  AdminLayout,
  AuthLayout,
  StorefrontLayout,
} from "../components/layout/MasterPages";
import { LoginPage } from "../features/auth/pages/LoginPage";
import { RegisterPage } from "../features/auth/pages/RegisterPage";
import { ProtectedRoute } from "../features/auth/ProtectedRoute";
import { AccountActions } from "../features/auth/AccountActions";

export function AppRouter() {
  return (
    <Routes>
      <Route element={<AuthLayout />}>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
      </Route>

      <Route
        element={
          <ProtectedRoute allowedRoles={["ADMINISTRADOR", "OPERADOR"]} />
        }
      >
        <Route
          path="/admin"
          element={<AdminLayout headerActions={<AccountActions />} />}
        >
          <Route
            index
            element={
              <div className="rounded-xl border border-line bg-white p-6">
                <h1 className="text-2xl font-bold text-ink">Área de gestión</h1>
                <p className="mt-2 text-muted">
                  Los módulos administrativos todavía no están disponibles.
                </p>
              </div>
            }
          />
        </Route>
      </Route>

      <Route element={<StorefrontLayout account={<AccountActions />} />}>
        <Route
          path="/"
          element={
            <div className="flex min-h-64 items-center justify-center rounded-xl border border-line bg-white px-6 py-12 shadow-panel">
              <h1 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">
                ShopCart
              </h1>
            </div>
          }
        />

        <Route
          path="*"
          element={
            <div className="flex min-h-64 flex-col items-center justify-center gap-4 rounded-xl border border-line bg-white px-6 py-12 text-center shadow-panel">
              <h1 className="text-4xl font-bold text-brand">404</h1>
              <p>Página no encontrada</p>
            </div>
          }
        />
      </Route>
    </Routes>
  );
}
