import { Route, Routes } from "react-router";
import { StorefrontLayout } from "../components/layout/MasterPages";

export function AppRouter() {
  return (
    <Routes>
      <Route element={<StorefrontLayout />}>
        <Route
          path="/"
          element={
            <div className="flex min-h-64 items-center justify-center rounded-xl border border-line bg-white px-6 py-12 shadow-panel">
              <h1 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">ShopCart</h1>
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
