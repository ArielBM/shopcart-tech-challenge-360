import type { ReactNode } from "react";
import { Button } from "./Button";

export interface DataTableColumn<T> {
  id: string;
  header: string;
  cell: (row: T) => ReactNode;
  sortable?: boolean;
}

export interface DataTableSort {
  field: string;
  direction: "asc" | "desc";
}

export interface DataTableProps<T> {
  caption: string;
  data: readonly T[];
  columns: readonly DataTableColumn<T>[];
  getRowKey: (row: T) => string | number;
  page: number;
  pageSize: number;
  /** Non-negative integer. Pass the API's BIGINT string to preserve its precision. */
  totalRecords: string | number | bigint;
  onPageChange: (page: number) => void;
  sort?: DataTableSort;
  onSortChange?: (sort: DataTableSort) => void;
  loading?: boolean;
  error?: string;
  emptyMessage?: string;
  className?: string;
}

// Rendering only: pagination and sorting callbacks request a new server result.
export function DataTable<T>({
  caption, data, columns, getRowKey, page, pageSize, totalRecords, onPageChange,
  sort, onSortChange, loading = false, error,
  emptyMessage = "No hay registros para mostrar.", className = "",
}: DataTableProps<T>) {
  if (!Number.isSafeInteger(page) || page < 1 || !Number.isSafeInteger(pageSize) || pageSize < 1) {
    throw new RangeError("DataTable requiere página y tamaño de página enteros positivos seguros.");
  }
  if (typeof totalRecords === "number" && !Number.isSafeInteger(totalRecords)) {
    throw new RangeError("DataTable requiere un total entero seguro o una cadena BIGINT.");
  }
  const total = BigInt(totalRecords);
  if (total < 0n) throw new RangeError("DataTable requiere un total de registros no negativo.");
  const pages = total === 0n ? 1n : (total + BigInt(pageSize) - 1n) / BigInt(pageSize);
  const blocked = loading || Boolean(error);
  const status = loading ? "loading" : error ? "error" : data.length === 0 ? "empty" : "success";

  return (
    <div className={`w-full min-w-0 max-w-full text-ink ${className}`}>
      <div
        role="region"
        aria-label={caption}
        tabIndex={0}
        className="w-full min-w-0 max-w-full overflow-x-auto rounded-lg border border-line focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      >
        <table aria-busy={loading} className="w-full border-collapse bg-white text-left text-sm">
          <caption className="sr-only">{caption}</caption>
          <thead className="border-b border-line bg-canvas text-ink">
            <tr>
              {columns.map((column) => {
                const active = sort?.field === column.id;
                const nextDirection = active && sort.direction === "asc" ? "desc" : "asc";
                return (
                  <th
                    key={column.id}
                    scope="col"
                    aria-sort={column.sortable ? active ? sort.direction === "asc" ? "ascending" : "descending" : "none" : undefined}
                    className="whitespace-nowrap px-4 py-3 font-semibold"
                  >
                    {column.sortable && onSortChange ? (
                      <button
                        type="button"
                        disabled={blocked}
                        aria-label={`Ordenar por ${column.header}: ${nextDirection === "asc" ? "ascendente" : "descendente"}`}
                        onClick={() => onSortChange({ field: column.id, direction: nextDirection })}
                        className="inline-flex min-h-11 items-center gap-2 rounded-sm text-left enabled:hover:text-brand focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:cursor-not-allowed disabled:opacity-50"
                      >
                        {column.header}
                        <span aria-hidden="true" className={active ? "text-brand" : "text-muted"}>
                          {active ? sort.direction === "asc" ? "↑" : "↓" : "↕"}
                        </span>
                      </button>
                    ) : column.header}
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody className="divide-y divide-line">
            {status === "success" ? data.map((row) => (
              <tr key={getRowKey(row)} className="hover:bg-brand-soft/40">
                {columns.map((column) => (
                  <td key={column.id} className="whitespace-nowrap px-4 py-3">{column.cell(row)}</td>
                ))}
              </tr>
            )) : (
              <tr>
                <td colSpan={columns.length || 1} className="px-4 py-10 text-center">
                  <p role={status === "error" ? "alert" : "status"} className={status === "error" ? "text-danger" : "text-muted"}>
                    {status === "loading" ? "Cargando registros…" : status === "error" ? error : emptyMessage}
                  </p>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-sm text-muted">Página {page} de {pages.toString()} · {total.toString()} registros</p>
        <nav aria-label={`Paginación de ${caption}`} className="flex flex-wrap gap-2">
          <Button variant="outline" aria-label="Página anterior" disabled={blocked || page <= 1} onClick={() => onPageChange(page - 1)}>
            Anterior
          </Button>
          <Button variant="outline" aria-label="Página siguiente" disabled={blocked || BigInt(page) >= pages || page === Number.MAX_SAFE_INTEGER} onClick={() => onPageChange(page + 1)}>
            Siguiente
          </Button>
        </nav>
      </div>
    </div>
  );
}
